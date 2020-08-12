SELECT * FROM (

	 SELECT DISTINCT
	    -1 AS ordinal_position,
	    CASE
	        WHEN '${PARTITION_TYPE}' = 'date' OR '${PARTITION_TYPE}' = 'timestamp' THEN 
				CONCAT('COALESCE( DATE_FORMAT( IF( WEEKDAY(',column_name,') IS NULL, ', 
					CASE '${PARTITION_FORMAT}' 
						WHEN 'YYYY' THEN '''1900''' 
						WHEN 'YYYYMM' THEN '''190001''' 
						WHEN 'YYYYWW' THEN '''190001''' 
						WHEN 'YYYYMMDD' THEN '''19000101''' 
					END, ', ',column_name,' ),', 
					CASE '${PARTITION_FORMAT}' 
						WHEN 'YYYY' THEN '''%Y''' 
						WHEN 'YYYYMM' THEN '''%Y%m''' 
						WHEN 'YYYYWW' THEN '''%Y%v''' 
						WHEN 'YYYYMMDD' THEN '''%Y%m%d''' 
					END,'), ',
					CASE '${PARTITION_FORMAT}' 
						WHEN 'YYYY' THEN '''1900''' 
						WHEN 'YYYYMM' THEN '''190001''' 
						WHEN 'YYYYWW' THEN '''190001''' 
						WHEN 'YYYYMMDD' THEN '''19000101'''
						ELSE '''190001''' 
				END,') AS partition_field')
	        WHEN '${PARTITION_TYPE}' = 'id' THEN CONCAT('(( floor( COALESCE(CAST(`',column_name,'` AS SIGNED ),1) / ( ${PARTITION_LENGTH} + 0.01 ) ) + 1 ) * ${PARTITION_LENGTH}) AS partition_field')
		END AS fields,
	    CASE
	        WHEN '${PARTITION_TYPE}' = 'date' OR '${PARTITION_TYPE}' = 'timestamp' THEN 
				CONCAT('COALESCE( DATE_FORMAT( IF( WEEKDAY(',column_name,') IS NULL, ', 
					CASE '${PARTITION_FORMAT}' 
						WHEN 'YYYY' THEN '''1900''' 
						WHEN 'YYYYMM' THEN '''190001''' 
						WHEN 'YYYYWW' THEN '''190001''' 
						WHEN 'YYYYMMDD' THEN '''19000101''' 
					END, ', ',column_name,' ),', 
					CASE '${PARTITION_FORMAT}' 
						WHEN 'YYYY' THEN '''%Y''' 
						WHEN 'YYYYMM' THEN '''%Y%m''' 
						WHEN 'YYYYWW' THEN '''%Y%v''' 
						WHEN 'YYYYMMDD' THEN '''%Y%m%d''' 
					END,'), ',
					CASE '${PARTITION_FORMAT}' 
						WHEN 'YYYY' THEN '''1900''' 
						WHEN 'YYYYMM' THEN '''190001''' 
						WHEN 'YYYYWW' THEN '''190001''' 
						WHEN 'YYYYMMDD' THEN '''19000101'''
						ELSE '''190001''' 
				END,')')
	        WHEN '${PARTITION_TYPE}' = 'id' THEN CONCAT('(( floor( COALESCE(CAST(`',column_name,'` AS SIGNED ),1) / ( ${PARTITION_LENGTH} + 0.01 ) ) + 1 ) * ${PARTITION_LENGTH})')
	    END AS casting,
	    'int' 											AS field_type,
		'{"name": "partition_field","type":"INTEGER"}'  AS json,
	    'partition_field' 							 	AS column_name,
	    0 											 	AS column_key,
		''                                              AS encoding
	FROM
	    information_schema.columns c
	WHERE
		LOWER( c.table_schema ) = LOWER('${INPUT_TABLE_SCHEMA}')
		AND
		LOWER( c.table_name ) = LOWER('${INPUT_TABLE_NAME}')
		AND
		LOWER( c.column_name ) = LOWER('${PARTITION_FIELD}')

    UNION ALL

	SELECT * FROM (
		SELECT DISTINCT
			0 AS ordinal_position,
			CASE WHEN '${CUSTOM_PRIMARY_KEY}'!= '' THEN CONCAT('CONCAT(','${CUSTOM_PRIMARY_KEY}',')',' AS custom_primary_key') ELSE CONCAT('CONCAT(', GROUP_CONCAT(LOWER(column_name)),')',' AS custom_primary_key')  end AS fields,
			CASE WHEN '${CUSTOM_PRIMARY_KEY}'!= '' THEN CONCAT('CONCAT(','${CUSTOM_PRIMARY_KEY}',')') ELSE CONCAT('CONCAT(', GROUP_CONCAT(LOWER(column_name)),')') END AS casting,
			'varchar(255)' 										AS field_type,
			'{"name": "custom_primary_key","type":"STRING"}' 	AS json,
			'custom_primary_key' 								AS column_name,
			1 													AS column_key,
			''                                                  AS encoding
		FROM
			information_schema.columns c
		WHERE
			LOWER( c.table_schema ) = LOWER('${INPUT_TABLE_SCHEMA}')
			AND
			LOWER( c.table_name ) = LOWER('${INPUT_TABLE_NAME}')
			AND
			c.column_key="PRI"
		ORDER BY 
			c.ordinal_position
	) x

	UNION ALL

    SELECT DISTINCT
        ordinal_position,
        CASE
            WHEN data_type IN ('datetime','timestamp') THEN CONCAT('COALESCE(DATE_FORMAT(IF( WEEKDAY(',column_name,') IS NULL', ',' , '''1900-01-01 00:00:00''', ',', column_name, '),', '''%Y-%m-%d %T', ' ${TIMEZONE_OFFSET}', '''), ', '''1900-01-01 00:00:00''', ') AS `',column_name,'`')
            WHEN data_type = 'date' THEN CONCAT('COALESCE(DATE_FORMAT(IF( WEEKDAY(',column_name,') IS NULL', ',' , '''1900-01-01''', ',', column_name, '),', '''%Y-%m-%d', '''), ', '''1900-01-01''', ') AS `',column_name,'`')
			WHEN data_type IN ('tinyint','smallint','mediumint', 'int', 'bigint') THEN CONCAT('CAST(`',column_name,'` AS SIGNED) AS `',column_name,'`')
            WHEN data_type IN ('text', 'longtext', 'mediumtext', 'tinytext', 'varchar') then concat('`', column_name, '` AS `',column_name,'`' )
            ELSE CONCAT('`',column_name,'`')
        END AS fields,
        CASE
            WHEN data_type IN ('datetime','timestamp') THEN CONCAT('COALESCE(DATE_FORMAT(IF( WEEKDAY(',column_name,') IS NULL', ',' , '''1900-01-01 00:00:00''', ',', column_name, '),', '''%Y-%m-%d %T', ' ${TIMEZONE_OFFSET}', '''), ', '''1900-01-01 00:00:00''', ')')
            WHEN data_type = 'date' THEN CONCAT('COALESCE(DATE_FORMAT(IF( WEEKDAY(',column_name,') IS NULL', ',' , '''1900-01-01''', ',', column_name, '),', '''%Y-%m-%d', '''), ', '''1900-01-01''', ')' )
			WHEN data_type IN ('tinyint','smallint','mediumint', 'int', 'bigint') THEN CONCAT('CAST(`',column_name,'` AS SIGNED)')
            WHEN data_type IN ('text', 'longtext', 'mediumtext', 'tinytext', 'varchar') then concat('`', column_name, '`' )
            ELSE CONCAT('`',column_name,'`')
        END AS casting,
		'' AS field_type,
		CONCAT('{"name": "', LOWER( column_name ), '","type":', 
			IF( data_type IN ("tinyint","smallint","mediumint", "int", "bit", "bigint"),'"INTEGER"', 
			IF( data_type IN ("float","double", "decimal"),'"FLOAT"', 
			IF( data_type IN ("timestamp","datetime", "decimal"),'"STRING"',
			IF( data_type = "datetime",'"STRING"', 
			IF( data_type = "date",'"DATE"', 
			IF( data_type = "boolean",'"BOOLEAN"', 
			IF( data_type = "time",'"TIME"','"STRING"' ))))))), ' }'
		) AS json,
		LOWER( column_name ) AS column_name,
        0 AS column_key,
		'' AS encoding
    FROM
        information_schema.columns c
    WHERE 1=1
	AND LOWER( c.table_schema ) = LOWER('${INPUT_TABLE_SCHEMA}')
   	AND LOWER( c.table_name ) = LOWER('${INPUT_TABLE_NAME}')
	AND UPPER(c.column_name) NOT IN (${METADATA_BLACKLIST})

    UNION ALL

    SELECT
        999 AS ordinal_position,
        CONCAT('CONCAT(','DATE_FORMAT(now(),','''','%Y-%m-%d %T', '''','),', '''' ,' ${TIMEZONE_OFFSET}', '''',') AS etl_load_date') AS fields,
		CONCAT('CONCAT(','DATE_FORMAT(now(),','''','%Y-%m-%d %T', '''','),', '''' ,' ${TIMEZONE_OFFSET}', '''',')') AS casting,
        'varchar(19)' 									AS field_type,
  		'{"name": "etl_load_date","type":"STRING"}' 	AS json,
        'etl_load_date' 								AS column_name,
        0 												AS column_key,
		''                                              AS encoding
) x
ORDER BY x.ordinal_position
