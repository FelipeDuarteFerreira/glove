SELECT * FROM (

    SELECT DISTINCT
        0 AS ordinal_position,
        CASE WHEN '${CUSTOM_PRIMARY_KEY}'!= '' THEN CONCAT('CONCAT(','${CUSTOM_PRIMARY_KEY}',')',' AS custom_primary_key') ELSE CONCAT('CONCAT(', GROUP_CONCAT(LOWER(column_name)),')',' AS custom_primary_key')  end AS fields,
		CASE WHEN '${CUSTOM_PRIMARY_KEY}'!= '' THEN CONCAT('CONCAT(','${CUSTOM_PRIMARY_KEY}',')') ELSE CONCAT('CONCAT(', GROUP_CONCAT(LOWER(column_name)),')') END AS casting,
		'varchar(255)' AS field_type,
		'' AS json,
        'custom_primary_key' AS column_name,
        1 AS column_key,
	'encode ${ENCODE}' AS encoding
    FROM
        information_schema.columns c
    WHERE
		LOWER( c.table_schema ) = LOWER('${INPUT_TABLE_SCHEMA}')
   		AND
		LOWER( c.table_name ) = LOWER('${INPUT_TABLE_NAME}')
        AND
        c.column_key="PRI"

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
			CASE data_type
			WHEN 'bit'      	THEN 'smallint'
			WHEN 'tinyint'      THEN 'smallint'
			WHEN 'smallint'     THEN 'smallint'
			WHEN 'mediumint'    THEN 'int'
          	WHEN 'int'          THEN 'int'
            WHEN 'bigint'       THEN 'bigint'
           	WHEN 'tinytext'     THEN 'varchar(65535)'
           	WHEN 'mediumtext'   THEN 'varchar(65535)'
           	WHEN 'text'         THEN 'varchar(65535)'
           	WHEN 'longtext'     THEN 'varchar(65535)'
            WHEN 'blob'         THEN 'varchar(65535)'
            WHEN 'mediumblob'   THEN 'varchar(65535)'
            WHEN 'date'         THEN 'date'
            WHEN 'datetime'     THEN 'timestamp'
            WHEN 'time'         THEN 'timestamp'
            WHEN 'timestamp'    THEN 'timestamp'
			WHEN 'decimal'      THEN  CONCAT('decimal','(', IF( NUMERIC_PRECISION > 38, 38, NUMERIC_PRECISION ) ,',',NUMERIC_SCALE,')')
            WHEN 'double'       THEN 'double precision'
            WHEN 'float'        THEN 'double precision'
            WHEN 'set'          THEN 'varchar(255)'
            WHEN 'enum'         THEN 'varchar(255)'
            WHEN 'char'         THEN CONCAT('varchar','(', CHARACTER_MAXIMUM_LENGTH + ROUND( ( CHARACTER_MAXIMUM_LENGTH - 1 ) / 2 ),')')
            WHEN 'varchar'      THEN CONCAT('varchar','(', CHARACTER_MAXIMUM_LENGTH + ROUND( ( CHARACTER_MAXIMUM_LENGTH - 1 ) / 2 ),')')
        END AS field_type,
		'' AS json,
		LOWER( column_name ) AS column_name,
        0 AS column_key,
	'encode ${ENCODE}' AS encoding
    FROM
        information_schema.columns c
    WHERE
		LOWER( c.table_schema ) = LOWER('${INPUT_TABLE_SCHEMA}')
   		AND
		LOWER( c.table_name ) = LOWER('${INPUT_TABLE_NAME}') 
        AND UPPER(column_name) NOT IN (${METADATA_BLACKLIST})

    UNION ALL

    SELECT
        999 AS ordinal_position,
        CONCAT('CONCAT(','DATE_FORMAT(now(),','''','%Y-%m-%d %T', '''','),', '''' ,' ${TIMEZONE_OFFSET}', '''',') AS etl_load_date') AS fields,
		CONCAT('CONCAT(','DATE_FORMAT(now(),','''','%Y-%m-%d %T', '''','),', '''' ,' ${TIMEZONE_OFFSET}', '''',')') AS casting,
        'timestamp' AS field_type,
  		'' AS json,
        'etl_load_date' 							AS column_name,
        0 											AS column_key,
	'encode ${ENCODE}' AS encoding
) x
ORDER BY x.ordinal_position
