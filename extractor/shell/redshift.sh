#!/bin/bash

export PGPASSWORD=${REDSHIFT_JDBC_PASSWORD};

# Redshift variables from kettle.properties.
REDSHIFT_URL=${REDSHIFT_JDBC_HOST}
REDSHIFT_USER=${REDSHIFT_JDBC_USER_NAME}
REDSHIFT_PORT=${REDSHIFT_JDBC_PORT}
REDSHIFT_DATASET=${REDSHIFT_JDBC_DB}

# Entity.
SCHEMA="${SCHEMA_NAME}"
TABLE="${TABLE_NAME}"

# Hash.
ENTITY_HASH=`echo -n ${TABLE} | md5sum | awk '{print substr($1,1,6)}'`
SCHEMA_HASH=`echo -n ${SCHEMA} | md5sum | awk '{print substr($1,1,6)}'`

# Caminho do bucket.
STORAGE_COPY_PATH="s3://${STORAGE_BUCKET}/${SCHEMA_HASH}_${SCHEMA}/${ENTITY_HASH}_${TABLE}/rawfile/copy/"
STORAGE_MANIFEST_PATH="s3://${STORAGE_BUCKET}/${SCHEMA_HASH}_${SCHEMA}/${ENTITY_HASH}_${TABLE}/manifest/"

# Arquivo de dados. 
DATA_FILE="${SCHEMA}_${TABLE}"

# Cria um schema no Redshift.
schema_check()
{
	echo "Running Redshift schema check at \"${SCHEMA}\"!"
    
	psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} << EOF
		CREATE SCHEMA IF NOT EXISTS ${SCHEMA};
EOF
	error_check
}

# Cria uma tabela no Redshift.
table_check()
{
	# Realiza a verificação da estrutura do schema.
	schema_check
	
	# Identifica o estilo de distribuição dos dados da tabela.
	if [ ${DISTSTYLE} == "key" ]; then
		if [ "${#DISTKEY}" -gt "0" ]; then
            if [ "${#SORTKEY}" -gt "0" ]; then
                psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} << EOF
                    CREATE TABLE IF NOT EXISTS "${SCHEMA}"."${TABLE}"
                    ( ${FIELD_NAME_AND_TYPE_LIST} )
                    diststyle key
                    distkey( ${DISTKEY} )
                    ${SORTKEY};
EOF
                error_check            
            else
                 psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} << EOF
                    CREATE TABLE IF NOT EXISTS "${SCHEMA}"."${TABLE}"
                    ( ${FIELD_NAME_AND_TYPE_LIST} )
                    diststyle key
                    distkey( ${DISTKEY} )
                    sortkey( ${DISTKEY} );
EOF
                error_check            
            fi
		else
            echo "A sortkey should be informed!"		
		fi			
	elif [ ${DISTSTYLE} == "all" ]; then
        if [ "${#SORTKEY}" -gt "0" ]; then
            psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} << EOF
                CREATE TABLE IF NOT EXISTS "${SCHEMA}"."${TABLE}"
                ( ${FIELD_NAME_AND_TYPE_LIST} )
                diststyle all
                ${SORTKEY};
EOF
            error_check
        else
            psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} << EOF
                CREATE TABLE IF NOT EXISTS "${SCHEMA}"."${TABLE}"
                ( ${FIELD_NAME_AND_TYPE_LIST} )
                diststyle all;
EOF
            error_check       
        fi		
	else
        if [ "${#SORTKEY}" -gt "0" ]; then
            psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} << EOF
                CREATE TABLE IF NOT EXISTS "${SCHEMA}"."${TABLE}"
                ( ${FIELD_NAME_AND_TYPE_LIST} )
                 ${SORTKEY};
EOF
            error_check        
        else
            psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} << EOF
                CREATE TABLE IF NOT EXISTS "${SCHEMA}"."${TABLE}"
                ( ${FIELD_NAME_AND_TYPE_LIST} );
EOF
            error_check        
        fi
	fi
}

# Executa carga full.
full_load()
{
	echo "Running full load!"

    cd ${RAWFILE_QUEUE_PATH}

	echo "Removing files from ${STORAGE_COPY_PATH}"
	aws s3 rm ${STORAGE_COPY_PATH} --recursive --only-show-errors

	echo "Uploading csv files to ${STORAGE_COPY_PATH}"
	aws s3 cp ${RAWFILE_QUEUE_PATH} ${STORAGE_COPY_PATH} --recursive --only-show-errors
	error_check
	
	echo "Uploading manifest file to ${STORAGE_MANIFEST_PATH}"
	aws s3 cp ${RAWFILE_QUEUE_MANIFEST_PATH} ${STORAGE_MANIFEST_PATH} --recursive --only-show-errors
	error_check	
	
	echo "Synchronizing Amazon S3 Buckets"
	sleep 45	

	psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} -v ON_ERROR_STOP=1 << EOF
    BEGIN;
      TRUNCATE TABLE "${SCHEMA}"."${TABLE}";

      COPY "${SCHEMA}"."${TABLE}" ( ${FIELD_NAME_LIST} )
      FROM '${STORAGE_MANIFEST_PATH}${DATA_FILE}.manifest' 
      ${REDSHIFT_UNLOAD_COPY_AUTHENTICATION}
      manifest
      csv
      delimiter '${DELIMITER}'
      gzip 
      timeformat 'YYYY-MM-DD HH:MI:SS'
      COMPUPDATE OFF
      STATUPDATE OFF;
    END;
EOF

	# Identifica a ocorrência de erros e interrompe processo.
	error_check	
	
    if [ ${DEBUG} = 0 ] ; then
        clean_up
    fi
}

# Executa carga delta.
delta_load()
{
	echo "Running delta load!"

    cd ${RAWFILE_QUEUE_PATH}

	echo "Removing files from ${STORAGE_COPY_PATH}"
	aws s3 rm ${STORAGE_COPY_PATH} --recursive --only-show-errors

	echo "Uploading csv files to ${STORAGE_COPY_PATH}"
	aws s3 cp ${RAWFILE_QUEUE_PATH} ${STORAGE_COPY_PATH} --recursive --only-show-errors
	error_check
	
	echo "Uploading manifest file to ${STORAGE_MANIFEST_PATH}"
	aws s3 cp ${RAWFILE_QUEUE_MANIFEST_PATH} ${STORAGE_MANIFEST_PATH} --recursive --only-show-errors
	error_check	
	
	echo "Synchronizing Amazon S3 Buckets"
	sleep 45	

	psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} -v ON_ERROR_STOP=1 << EOF
		BEGIN;
			CREATE TABLE #tmp_${TABLE} ( like "${SCHEMA}"."${TABLE}" ); 

			COPY #tmp_${TABLE} ( ${FIELD_NAME_LIST} )
			FROM '${STORAGE_MANIFEST_PATH}${DATA_FILE}.manifest' 
			${REDSHIFT_UNLOAD_COPY_AUTHENTICATION}
			manifest
			csv
			delimiter '${DELIMITER}'
			gzip 
			timeformat 'YYYY-MM-DD HH:MI:SS';

			DELETE FROM 
				"${SCHEMA}"."${TABLE}" 
			WHERE 
				"${SCHEMA}"."${TABLE}".custom_primary_key 
			IN (
				SELECT 
					custom_primary_key 
				FROM 
					#tmp_${TABLE}
			);

			INSERT INTO "${SCHEMA}"."${TABLE}" ( ${FIELD_NAME_LIST} ) 
			SELECT 
				${FIELD_NAME_LIST}
			FROM 
				#tmp_${TABLE};
				
			ANALYZE "${SCHEMA}"."${TABLE}" predicate columns;	
		END;
EOF

	# Identifica a ocorrência de erros e interrompe processo.
	error_check	
	
    if [ ${DEBUG} = 0 ] ; then
        clean_up
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
	echo "Dropping table ${REDSHIFT_DATASET}.\"${SCHEMA}\".\"${TABLE}\"!"
	psql -h ${REDSHIFT_URL} -U ${REDSHIFT_USER} -w -d ${REDSHIFT_DATASET} -p ${REDSHIFT_PORT} << EOF
			DROP TABLE IF EXISTS "${SCHEMA}"."${TABLE}";
EOF

	# Realiza a verificação da estrutura das tabelas.
	table_check
fi

# Identifica a quantidade de arquivos a serem processados.
QUEUE_FILE_COUNT=`ls ${RAWFILE_QUEUE_PATH}*${DATA_FILE}* |wc -l`

# Identifica se o arquivo contém ao menos uma linha.
if [ ${QUEUE_FOLDER_SIZE} -lt 1000 ]; then
    QUEUE_FILE_COUNT=`cat ${RAWFILE_QUEUE_PATH}*${DATA_FILE}* |wc -l`
fi

# Executa o processo de carga e criação de entidades.
if [ ${QUEUE_FILE_COUNT} -gt 0 ]; then
	cd ${RAWFILE_QUEUE_PATH}

	echo "Work area:"
	echo "${RAWFILE_QUEUE_PATH}"
	
    echo "Credentials:"
    echo "URL ${REDSHIFT_URL}"
    echo "User ${REDSHIFT_USER}"
    echo "Dataset ${REDSHIFT_DATASET}"
    echo "Port ${REDSHIFT_PORT}"
    echo "Password provided by kettle.properties parameter"
	
    table_check

	# Particiona o arquivo intermediário.
	echo "Splitting csv file!"
	if [ ${DEBUG} = 1 ] ; then
		echo "DEBUG:java -jar ${GLOVE_HOME}/extractor/lib/converter.jar \
			--folder=${RAWFILE_QUEUE_PATH} \
			--filename=*.csv \
			--delimiter=${DELIMITER} \
			--target=csv \
			--splitStrategy=${SPLIT_STRATEGY} \
			--partition=-1 \
			--thread=${THREAD} \	
			--escape=${QUOTE_ESCAPE} \			
			--header \
			--replace \
			--debug=${DEBUG}"
	fi

    java -jar ${GLOVE_HOME}/extractor/lib/converter.jar \
		--folder=${RAWFILE_QUEUE_PATH} \
		--filename=*.csv \
		--delimiter=${DELIMITER} \
		--target=csv \
		--splitStrategy=${SPLIT_STRATEGY} \
		--partition=-1 \
		--thread=${THREAD} \
		--escape=${QUOTE_ESCAPE} \
		--header \
		--replace \
		--debug=${DEBUG}			
	error_check

	# Compacta os arquivos particionados.
	echo "Compacting csv files!"
	for i in `ls *.csv`
	do
		pigz $i
		error_check
	done
	
	# Gera o arquivo de manifesto para COPY no Redshift.
	echo "Generating manifest file!"
	mkdir -p ${RAWFILE_QUEUE_MANIFEST_PATH}
	
	echo { > ${RAWFILE_QUEUE_MANIFEST_PATH}${DATA_FILE}.manifest
	echo  -e '\t' \"entries\": [ >> ${RAWFILE_QUEUE_MANIFEST_PATH}${DATA_FILE}.manifest
	
	TOTAL_FILES=`ls ${RAWFILE_QUEUE_PATH}*.gz | wc -l`
	FILE_COUNT=1

	for i in `ls *.gz`
	do  
		if [ $FILE_COUNT -eq $TOTAL_FILES ]; then 
			COMMA=""
		else 
			COMMA=","
		fi
		
		echo -e '\t\t\t' {\"url\":\"${STORAGE_COPY_PATH}$i\", \"mandatory\":true}${COMMA} >> ${RAWFILE_QUEUE_MANIFEST_PATH}${DATA_FILE}.manifest

		FILE_COUNT=$((++FILE_COUNT))
	done
	
	echo ] >> ${RAWFILE_QUEUE_MANIFEST_PATH}${DATA_FILE}.manifest
	echo } >> ${RAWFILE_QUEUE_MANIFEST_PATH}${DATA_FILE}.manifest

    # Identifica se o APPEND está habilitado no módulo de arquivo.
	if [ ${MODULE} == "file" ] && [ ${FILE_OUTPUT_MODE} == "append" ]; then
		delta_load
	else
        # Identifica o tipo de carga que será realizado.
        if [ "${#DELTA_FIELD_IN_METADATA}" -gt "0" ]; then
            delta_load
        else
            full_load
        fi
    fi
fi
