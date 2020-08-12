SELECT * FROM (

    SELECT DISTINCT
        0 AS ordinal_position,
        CASE WHEN '${CUSTOM_PRIMARY_KEY}' != '' THEN CONCAT('CONCAT(','${CUSTOM_PRIMARY_KEY}',')', ' AS custom_primary_key') ELSE CONCAT( STRING_AGG( (a.attname||'::varchar'), '||' ), ' as custom_primary_key' ) END AS fields,
		CASE WHEN '${CUSTOM_PRIMARY_KEY}' != '' THEN CONCAT('CONCAT(','${CUSTOM_PRIMARY_KEY}',')') ELSE CONCAT( STRING_AGG( (a.attname||'::varchar'), '||' ) ) END AS casting,
		'varchar(255)' AS field_type,
		'' AS json,
        'custom_primary_key' AS column_name,
        1 AS column_key,
		'encode ${ENCODE}' AS encoding
    FROM pg_index i
         JOIN pg_attribute a ON a.attrelid = i.indrelid  AND a.attnum = any(i.indkey)
    WHERE
        i.indrelid = lower('${INPUT_TABLE_SCHEMA}.${INPUT_TABLE_NAME}')::regclass
        AND
        i.indisprimary
    GROUP BY ordinal_position, json, column_name, column_key

	UNION ALL

    SELECT DISTINCT
        ordinal_position,
        CASE
            WHEN data_type = 'date' THEN 'TO_CHAR ( ' || column_name || ' , ' || chr(39) || 'YYYY-MM-DD' ||  chr(39) || ') as ' || column_name
            WHEN data_type IN ( 'timestamp with time zone', 'timestamp without time zone' ) THEN 'TO_CHAR ( ' || column_name || ' , ' || chr(39) || 'YYYY-MM-DD HH24:MI:SS ' || '${TIMEZONE_OFFSET}' || chr(39) || ') as ' || column_name
            WHEN data_type IN ( '"char"', 'character varying', 'text' ) then  column_name || ' as ' || column_name
            ELSE column_name
        END AS fields,
        CASE
            WHEN data_type = 'date' THEN 'TO_CHAR ( ' || column_name || ' , ' || chr(39) || 'YYYY-MM-DD' ||  chr(39) || ')'
            WHEN data_type IN ( 'timestamp with time zone', 'timestamp without time zone' ) THEN 'TO_CHAR ( ' || column_name || ' , ' || chr(39) || 'YYYY-MM-DD HH24:MI:SS ' || '${TIMEZONE_OFFSET}' || chr(39) || ')'
            WHEN data_type IN ( '"char"', 'character varying', 'text' ) then  column_name
            ELSE column_name
        END AS casting,
        CASE data_type
            WHEN 'smallint'		                 THEN 'smallint'
            WHEN 'integer'		                 THEN 'int'
            WHEN 'bigint' 		                 THEN 'bigint'
            WHEN '"char"'			             THEN 'varchar'||'(' || COALESCE( character_maximum_length, 255 ) ||')'
            WHEN 'character varying'             THEN 'varchar'||'(' || COALESCE( character_maximum_length, 255 ) ||')'
            WHEN 'text'			                 THEN 'varchar(65535)'
            WHEN 'double precision'	             THEN 'double precision'
            WHEN 'date'			                 THEN 'date'
            WHEN 'timestamp with time zone'		 THEN 'timestamp'
            WHEN 'timestamp without time zone'	 THEN 'timestamp'
            WHEN 'time without time zone'	     THEN 'timestamp'
            WHEN 'real'	                         THEN 'double precision'
            WHEN 'numeric'		                 THEN 'decimal'||'('|| COALESCE(  numeric_precision, 16 ) ||','|| COALESCE(  numeric_scale, 4 ) ||')'
            WHEN 'boolean' 		                 THEN 'boolean'
        END AS field_type,
		'' AS json,
		LOWER( column_name ) AS column_name,
        0 AS column_key,
		'encode ${ENCODE}' AS encoding
    FROM
		information_schema.columns c
   	WHERE
		lower( c.table_schema ) = lower('${INPUT_TABLE_SCHEMA}')
   		AND
		lower( c.table_name ) = lower('${INPUT_TABLE_NAME}')
        AND UPPER(column_name) NOT IN (${METADATA_BLACKLIST})

    UNION ALL

    SELECT
        998 AS ordinal_position,
        ( 'to_char( now(),' || chr(39) || 'YYYY-MM-DD HH24:MI:SS ' || '${TIMEZONE_OFFSET}' || chr(39) || ') as etl_load_date' ) AS fields,
		( 'to_char( now(),' || chr(39) || 'YYYY-MM-DD HH24:MI:SS ' || '${TIMEZONE_OFFSET}' || chr(39) || ')' ) AS casting,
        'timestamp' AS field_type,
  		'' AS json,
        'etl_load_date' 							AS column_name,
        0 											AS column_key,
		'encode ${ENCODE}' AS encoding
) x
ORDER BY x.ordinal_position
