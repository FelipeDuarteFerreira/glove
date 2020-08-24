#!/bin/bash

# Google Tools.
export PATH=$PATH:${GOOGLE_TOOLS_HOME}:${GOOGLE_TOOLS_HOME}/bin

# Entity.
SCHEMA="${SCHEMA_NAME}"
TABLE="${TABLE_NAME}"

# Caminho do bucket.
STORAGE_QUEUE_PATH="gs://${GOOGLE_CLOUD_BUCKET}/${SCHEMA}/${TABLE}/rawfile/queue/"

# Arquivo de dados. 
DATA_FILE="${SCHEMA}_${TABLE}"

# Executa a carga particionada.
partition_load()
{
	echo "Running partition load!"
	cd ${RAWFILE_QUEUE_PATH}

	#Particiona o arquivo contendo os dados. 
	echo "Partitioning data file delimited by ${DELIMITER}!"
	if [ ${IS_PARALLEL} = 1 ]; then
		echo "Paralle actived"	
			
		if [ ${DELIMITER} == ";" ]; then
			cat ${RAWFILE_QUEUE_FILE} | parallel --no-notice --pipe -L1000 --jobs 4 awk \'BEGIN{ FS=OFS=\"\;\" } { gsub\(/\\W/, \"\", \$1\)\; gsub\( \"\\042\", \"\", \$2\)\; print\>\$1\"_tmp_{#}\" }\'
		else
			cat ${RAWFILE_QUEUE_FILE} | parallel --no-notice --pipe -L1000 --jobs 4 awk \'BEGIN{ FS=OFS=\"\,\" } { gsub\(/\\W/, \"\", \$1\)\; gsub\( \"\\042\", \"\", \$2\)\; print\>\$1\"_tmp_{#}\" }\'
		fi
		error_check 	
	else
		if [ ${DELIMITER} == ";" ]; then
			awk 'BEGIN{ FS=OFS=";" } { gsub(/\W/, "", $1); gsub( "\042", "", $2); print>$1".csv" }' ${RAWFILE_QUEUE_FILE}
		else
			awk 'BEGIN{ FS=OFS="," } { gsub(/\W/, "", $1); gsub( "\042", "", $2); print>$1".csv" }' ${RAWFILE_QUEUE_FILE}
		fi
		error_check
	fi

    # Remove o arquivo original, mantendo apenas as partições. 
	echo "Removing file ${RAWFILE_QUEUE_FILE}!"
	rm -f ${RAWFILE_QUEUE_FILE}
	error_check

	# Une os fragmentos da partição criados por cada executor do parallel. 
	if [ ${IS_PARALLEL} = 1 ]; then
		echo "Removing temporary files!"
		
		for i in `ls | cut -d"_" -f1 | uniq`
		do 
			cat ${i}_tmp_* > ${i}.csv
			rm -f ${i}_tmp_*
		done
		error_check	
	fi		
	
	# Compacta o arquivo de cada partição. 
	echo "Compacting csv files!"
	for i in `ls *.csv`
	do
		pigz $i
		error_check
	done
	
	# Envia os arquivos para o storage.
	echo "Copying files to ${STORAGE_QUEUE_PATH} from ${RAWFILE_QUEUE_PATH}"
	gsutil -q -m rm ${STORAGE_QUEUE_PATH}*
	gsutil -q -m cp ${RAWFILE_QUEUE_PATH}* ${STORAGE_QUEUE_PATH}
	error_check

	# Envia os dados para a staging area.
	echo "Loading data to ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} from ${STORAGE_QUEUE_PATH}"
	bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} 
	bq mk --project_id=${BIG_QUERY_PROJECT_ID} ${CUSTOM_SCHEMA}${SCHEMA_NAME}
	bq load --project_id=${BIG_QUERY_PROJECT_ID} --field_delimiter="${DELIMITER}" ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} ${STORAGE_QUEUE_PATH}* ${METADATA_JSON_FILE}
	error_check
	
    # Percorre o arquivo de cada partição. 
    for i in `ls *.gz`
    do
        # Identifica a partição. 
        PARTITION=`echo $i | cut -d '.' -f 1`
        error_check

        # Identifica se a partição existe no BigQuery. 
        echo "Cheking partition ${PARTITION}!"
		bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE}_${PARTITION}
		bq query --allow_large_results --project_id=${BIG_QUERY_PROJECT_ID} --use_legacy_sql=false "SELECT COUNT(1) AS TOTAL_ROWS_IN_PARTITION FROM ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE}_${PARTITION}"

		if [ $? -eq 0 ]; then
			PARTITION_EXISTS=1
		else
			PARTITION_EXISTS=0
		fi		
		
		# Atualiza/Cria a partição no BigQuery. 
		if [ "${PARTITION_EXISTS}" -eq "1" ]; then 
			bq query --allow_large_results --project_id=${BIG_QUERY_PROJECT_ID} --use_legacy_sql=false --destination_table=${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE}_${PARTITION} "SELECT R.* FROM ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE}_${PARTITION} R LEFT JOIN ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} S ON R.CUSTOM_PRIMARY_KEY=S.CUSTOM_PRIMARY_KEY  WHERE S.CUSTOM_PRIMARY_KEY IS NULL AND R.PARTITION_FIELD = ${PARTITION};"  
			error_check
			
			bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE}_${PARTITION}
			bq query --allow_large_results --project_id=${BIG_QUERY_PROJECT_ID} --use_legacy_sql=false --destination_table=${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE}_${PARTITION} "SELECT R.* FROM ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE}_${PARTITION} R UNION ALL SELECT S.* FROM ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} S WHERE S.PARTITION_FIELD = ${PARTITION};"
			
			error_check
			bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE}_${PARTITION}
		else
			bq query --allow_large_results --project_id=${BIG_QUERY_PROJECT_ID} --use_legacy_sql=false --destination_table=${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE}_${PARTITION} "SELECT * FROM ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} WHERE PARTITION_FIELD = ${PARTITION};"  
			error_check
		fi			
    done	

    # Remove os arquivos temporários.
    if [ ${DEBUG} = 0 ] ; then
		clean_up
        
		bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE}	
		gsutil -q -m rm ${STORAGE_QUEUE_PATH}*
    fi
}

# Executa a carga delta.
delta_load()
{
	echo "Running delta load!"
	cd ${RAWFILE_QUEUE_PATH}
	
	# Particiona o arquivo de dados.
	echo "Splitting csv file delimited by ${DELIMITER}!"
	split -l 1000000 --numeric-suffixes=1 --additional-suffix=.csv ${RAWFILE_QUEUE_FILE} ${DATA_FILE}
	error_check	
	
	# Remove o arquivo original, mantendo apenas as partições. 
	echo "Removing file ${RAWFILE_QUEUE_FILE}!"
	rm -f ${RAWFILE_QUEUE_FILE}
	error_check	
	
	# Compacta o arquivo de cada partição. 
	echo "Compacting csv files!"
	for i in `ls *.csv`
	do
		pigz $i
		error_check
	done	
	
	# Envia os arquivos para o storage.
	echo "Copying files to ${STORAGE_QUEUE_PATH} from ${RAWFILE_QUEUE_PATH}"
	gsutil -q -m rm ${STORAGE_QUEUE_PATH}*
	gsutil -q -m cp ${RAWFILE_QUEUE_PATH}* ${STORAGE_QUEUE_PATH}
	error_check
	
	# Envia os dados para a staging area.
	echo "Loading table ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} from ${STORAGE_QUEUE_PATH}"
	bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} 
	bq mk --project_id=${BIG_QUERY_PROJECT_ID} ${CUSTOM_SCHEMA}${SCHEMA_NAME}
	bq load --project_id=${BIG_QUERY_PROJECT_ID} --field_delimiter="${DELIMITER}" ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} ${STORAGE_QUEUE_PATH}* ${METADATA_JSON_FILE}
	error_check
	
	# Monta a tabela temporária.
	echo "Appending to table ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} from ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE}"
	bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} 
	bq query --allow_large_results --project_id=${BIG_QUERY_PROJECT_ID} --use_legacy_sql=false --destination_table=${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} "SELECT R.* FROM ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} R LEFT JOIN ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} S ON R.CUSTOM_PRIMARY_KEY=S.CUSTOM_PRIMARY_KEY WHERE S.CUSTOM_PRIMARY_KEY IS NULL;"
	bq query --allow_large_results --project_id=${BIG_QUERY_PROJECT_ID} --use_legacy_sql=false --append_table=true --destination_table=${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} "SELECT R.* FROM ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} R;"
	error_check
	
	# Remove a tabela principal.
	echo "Removing table ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} from ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE}"
	bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} 
	
	# Copia os dados da tabela temporária para a tabela principal.
	echo "Loading data to table ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} from ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE}"
	bq cp --project_id=${BIG_QUERY_PROJECT_ID} ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE}
	error_check

    # Remove os arquivos temporários.
    if [ ${DEBUG} = 0 ] ; then
		clean_up
        
		bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} 
		bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} 
		gsutil -q -m rm ${STORAGE_QUEUE_PATH}*
    fi	
}

# Executa a carga full.
full_load()
{
	echo "Running full load!"
    cd ${RAWFILE_QUEUE_PATH}
	
	# Particiona o arquivo de dados.
	echo "Splitting csv file delimited by ${DELIMITER}!"
	split -l 1000000 --numeric-suffixes=1 --additional-suffix=.csv ${RAWFILE_QUEUE_FILE} ${DATA_FILE}
	error_check	
	
	# Remove o arquivo original, mantendo apenas as partições. 
	echo "Removing file ${RAWFILE_QUEUE_FILE}!"
	rm -f ${RAWFILE_QUEUE_FILE}
	error_check	
	
	# Compacta o arquivo de cada partição. 
	echo "Compacting csv files!"
	for i in `ls *.csv`
	do
		pigz $i
		error_check
	done	
	
	# Envia os arquivos para o storage.
	echo "Copying files to ${STORAGE_QUEUE_PATH} from ${RAWFILE_QUEUE_PATH}"
	gsutil -q -m rm ${STORAGE_QUEUE_PATH}*
	gsutil -q -m cp ${RAWFILE_QUEUE_PATH}* ${STORAGE_QUEUE_PATH}
	error_check
	
	# Envia os dados para a tabela temporária.
	echo "Loading table ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} from ${STORAGE_QUEUE_PATH}"
	bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} 
	bq mk --project_id=${BIG_QUERY_PROJECT_ID} ${CUSTOM_SCHEMA}${SCHEMA_NAME}
	bq load --project_id=${BIG_QUERY_PROJECT_ID} --field_delimiter="${DELIMITER}" ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} ${STORAGE_QUEUE_PATH}* ${METADATA_JSON_FILE}
	error_check	
	
	# Remove a tabela principal.
	echo "Removing table ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} from ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE}"
	bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} 	
	
	# Copia os dados da tabela temporária para a tabela principal.
	echo "Loading data to table ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} from ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE}"
	bq cp --project_id=${BIG_QUERY_PROJECT_ID} ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} 
	error_check
	
    # Remove os arquivos temporários.
    if [ ${DEBUG} = 0 ] ; then
		clean_up
        
		bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} 
		bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} 
		gsutil -q -m rm ${STORAGE_QUEUE_PATH}*
    fi
}

# Realiza a limpeza dos arquivos temporários.
clean_up()
{
    if [ ${MODULE} != "file" ]; then
        echo "Removing temporary folder ${QUEUE_PATH}"
        cd ${GLOVE_TEMP}
        rm -rf ${QUEUE_PATH}
    fi
}

# Identifica a ocorrência de erros e interrompe processo.
error_check()
{
	if [ $? -gt 0 ]; then
        echo "An error has occurred :_("

        # Remove os arquivos temporários.
        if [ ${DEBUG} = 0 ] ; then
            clean_up
            
			bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.stg_${TABLE} 
			bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.tmp_${TABLE} 
			gsutil -q -m rm ${STORAGE_QUEUE_PATH}*
        fi

		exit 1
	fi
}

# Identifica o tamanho do diretório de trabalho.
QUEUE_FOLDER_SIZE=`du -s ${RAWFILE_QUEUE_PATH} | cut -f1`

# Limita o volume de dados.
if [ ${QUEUE_FOLDER_SIZE} -gt ${QUEUE_FILES_SIZE_LIMIT} ]; then
	echo "You are trying processing ${QUEUE_FOLDER_SIZE} KB :0. Please, reduce the amount of data!"
	
	# Remove os arquivos temporários.
	if [ ${DEBUG} = 0 ] ; then
		clean_up
	fi
	
	exit 1
else
	echo "${QUEUE_FOLDER_SIZE} KB of data will be processed ( ${QUEUE_FILES_SIZE_LIMIT} KB is the limit )!"
fi

# Identifica se deve recriar a tabela.
if [ ${IS_RECREATE} = 1 ]; then
    # Dropa a tabela para que possa ser recriada.
	echo "Removing table ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE}!"
	bq rm --project_id=${BIG_QUERY_PROJECT_ID} -f -t ${CUSTOM_SCHEMA}${SCHEMA_NAME}.${TABLE} 
fi

# Identifica a quantidade de arquivos a serem processados.
QUEUE_FILE_COUNT=`ls ${RAWFILE_QUEUE_PATH}*${DATA_FILE}* |wc -l`

# Identifica se o arquivo contém ao menos uma linha.
if [ ${QUEUE_FOLDER_SIZE} -lt 1000 ]; then
    QUEUE_FILE_COUNT=`cat ${RAWFILE_QUEUE_PATH}*${DATA_FILE}* |wc -l`
fi

# Executa o processo de carga e criação de entidades.
if [ ${QUEUE_FILE_COUNT} -gt 0 ]; then
	echo "Work area:"
	echo "${RAWFILE_QUEUE_PATH}"

    # Identifica se é uma named query.
    if [ ${MODULE} == "query" ]; then
	
		# Identifica se deve exportar o csv intermediário para o storage.
		if [ ${IS_EXPORT} = 1 ]; then
		
			# Compacta o arquivo csv.
			pigz -c ${RAWFILE_QUEUE_FILE} > ${RAWFILE_QUEUE_FILE}.gz

			# Define o storage de exportação.
			if [ "${#EXPORT_BUCKET}" -gt "0" ]; then
				# Envia o arquivo para o storage.
				echo "Exporting resultset to ${EXPORT_BUCKET}!"
				gsutil -q -m rm ${EXPORT_BUCKET}*
				gsutil -q -m cp ${RAWFILE_QUEUE_FILE}.gz ${EXPORT_BUCKET}
				error_check	

				# Remove o arquivo compactado do diretório.
				rm -rf ${RAWFILE_QUEUE_FILE}.gz
				
				# Finaliza o processo de exportação.
				if [ ${ONLY_EXPORT} = 1 ]; then
					echo "Exporting finished!"
					exit 0
				fi
			else
				echo "EXPORT_BUCKET was not defined!"
			fi
		fi 

		# Remove o header do csv intermediário.
		echo "Removing header from ${RAWFILE_QUEUE_FILE}!"
		tail -n +2 ${RAWFILE_QUEUE_FILE} > ${RAWFILE_QUEUE_FILE}.tmp
		mv -f ${RAWFILE_QUEUE_FILE}.tmp ${RAWFILE_QUEUE_FILE};
    fi

	# Identifica o tipo de carga que será realizado.
	if [ "${#PARTITION_FIELD}" -gt "0" ]; then
		partition_load		
	else
		if [ "${#DELTA_FIELD_IN_METADATA}" -gt "0" ]; then
			delta_load			
		else
			full_load
		fi
	fi
else
	echo "Nothing to load from ${RAWFILE_QUEUE_PATH} :/"
fi
