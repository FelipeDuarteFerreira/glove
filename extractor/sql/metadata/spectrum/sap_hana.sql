SELECT * FROM (
    SELECT
        fields,
        casting,
		field_type,
        json,
        column_name,
        column_key,
		encoding
    FROM (

        SELECT
            -1 AS POSITION,
           	CASE
				WHEN '${PARTITION_TYPE}' = 'date' OR '${PARTITION_TYPE}' = 'timestamp' THEN 'TO_CHAR( TO_DATE( TO_BIGINT( CASE WHEN TO_BIGINT("' || COLUMN_NAME || '") = 0 THEN ''19000101'' ELSE "' || COLUMN_NAME || '" END ) ), ''${PARTITION_FORMAT}'' ) AS partition_field'
          		WHEN '${PARTITION_TYPE}' = 'id' THEN 'TO_BIGINT ( ( FLOOR( COALESCE( TO_BIGINT("' || COLUMN_NAME || '"), 1 ) / ( ${PARTITION_LENGTH} + 0.01 ) ) + 1 ) * ${PARTITION_LENGTH} ) AS partition_field'
           	END AS fields,
     		CASE
				WHEN '${PARTITION_TYPE}' = 'date' OR '${PARTITION_TYPE}' = 'timestamp' THEN 'TO_CHAR( TO_DATE( TO_BIGINT( CASE WHEN TO_BIGINT("' || COLUMN_NAME || '") = 0 THEN ''19000101'' ELSE "' || COLUMN_NAME || '" END ) ), ''${PARTITION_FORMAT}'' )'
          		WHEN '${PARTITION_TYPE}' = 'id' THEN 'TO_BIGINT ( ( FLOOR( COALESCE( TO_BIGINT("' || COLUMN_NAME || '"), 1 ) / ( ${PARTITION_LENGTH} + 0.01 ) ) + 1 ) * ${PARTITION_LENGTH} )'
           	END AS casting,
            'int' AS field_type,
			'{"name": "partition_field","type":["null", "int"], "default": null}' AS json,
            'partition_field' 							 AS column_name,
            0 											 AS column_key,
			''                                           AS encoding
        FROM
            (
		SELECT
			 SCHEMA_NAME
			,TABLE_NAME
			,COLUMN_NAME
			,DATA_TYPE_NAME
			,POSITION
			,LENGTH
			,SCALE
		FROM TABLE_COLUMNS
		WHERE
		LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
		AND 
		LOWER( TABLE_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )
		
		UNION ALL
		
		SELECT
			 SCHEMA_NAME
			,VIEW_NAME AS TABLE_NAME
			,COLUMN_NAME
			,DATA_TYPE_NAME
			,POSITION
			,LENGTH
			,SCALE
		FROM VIEW_COLUMNS
		WHERE
		LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
		AND 
		LOWER( VIEW_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )
            )q
        WHERE
            LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
            AND
            LOWER( TABLE_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )
            AND
	   LOWER( COLUMN_NAME ) = LOWER( REPLACE( '${PARTITION_FIELD}', '"', '' ) )

		UNION ALL

        SELECT
            0 AS POSITION,
            CASE
            	WHEN '${CUSTOM_PRIMARY_KEY}' != '' THEN '('||REPLACE('${CUSTOM_PRIMARY_KEY}',',','||')||') AS custom_primary_key'  ELSE CONCAT( STRING_AGG( '"' || dd03l.fieldname || '"', '||' ), ' AS custom_primary_key' )
            END AS fields,
            CASE
            	WHEN '${CUSTOM_PRIMARY_KEY}' != '' THEN '('||REPLACE('${CUSTOM_PRIMARY_KEY}',',','||' )||')' ELSE STRING_AGG( '"' || dd03l.fieldname || '"', '||' )
            END AS casting,
            'varchar(255)' AS field_type,
            '{"name": "custom_primary_key","type":["null", "string"], "default": null}' AS json,
            'custom_primary_key' AS column_name,
            1 AS column_key,
			'' AS encoding
        FROM
            ${INPUT_TABLE_SCHEMA}.dd03l
        WHERE
            LOWER( dd03l.tabname ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )
            AND
            dd03l.keyflag = 'X'
        GROUP BY dd03l.tabname

        UNION ALL
        
        SELECT DISTINCT
            POSITION,
            CASE
                WHEN DATA_TYPE_NAME = 'DATE' THEN 'TO_CHAR ( ' || COLUMN_NAME || ' , ' || '''' || 'YYYY-MM-DD' ||  '''' || ') AS ' || CASE '${FIELD_HAS_PREFIX}' WHEN '1' THEN REPLACE_REGEXPR( '\/' IN REPLACE_REGEXPR( '^\W|^_' IN COLUMN_NAME WITH '' ) WITH '_' ) ELSE REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' ) END
                WHEN DATA_TYPE_NAME IN  ( 'TIME', 'SECONDDATE', 'TIMESTAMP' ) THEN 'CONCAT( TO_CHAR ( ' || COLUMN_NAME || ' , ' || '''' || 'YYYY-MM-DD HH24:MI:SS' || '''' || '),' || '''' || ' ${TIMEZONE_OFFSET}' || '''' || ') AS ' || CASE '${FIELD_HAS_PREFIX}' WHEN '1' THEN REPLACE_REGEXPR( '\/' IN REPLACE_REGEXPR( '^\W|^_' IN COLUMN_NAME WITH '' ) WITH '_' ) ELSE REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' ) END
                WHEN DATA_TYPE_NAME in ( 'VARCHAR', 'NVARCHAR', 'ALPHANUM', 'SHORTTEXT', 'BLOB', 'CLOB', 'NCLOB', 'TEXT' ) then '"' || COLUMN_NAME || '"' || ' as ' || CASE '${FIELD_HAS_PREFIX}' WHEN '1' THEN REPLACE_REGEXPR( '\/' IN REPLACE_REGEXPR( '^\W|^_' IN COLUMN_NAME WITH '' ) WITH '_' ) ELSE REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' ) END
                WHEN DATA_TYPE_NAME in ( 'VARBINARY' ) then 'TO_NVARCHAR (' || COLUMN_NAME || ')' || ' as ' || CASE '${FIELD_HAS_PREFIX}' WHEN '1' THEN REPLACE_REGEXPR( '\/' IN REPLACE_REGEXPR( '^\W|^_' IN COLUMN_NAME WITH '' ) WITH '_' ) ELSE REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' ) END
                ELSE '"' || COLUMN_NAME || '"' || ' AS ' || CASE '${FIELD_HAS_PREFIX}' WHEN '1' THEN REPLACE_REGEXPR( '\/' IN REPLACE_REGEXPR( '^\W|^_' IN COLUMN_NAME WITH '' ) WITH '_' ) ELSE REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' ) END
            END AS fields,
            CASE
                WHEN DATA_TYPE_NAME = 'DATE' THEN 'TO_CHAR ( ' || COLUMN_NAME || ' , ' || '''' || 'YYYY-MM-DD' ||  '''' || ')'
                WHEN DATA_TYPE_NAME IN  ( 'TIME', 'SECONDDATE', 'TIMESTAMP' ) THEN 'CONCAT( TO_CHAR ( ' || COLUMN_NAME || ' , ' || '''' || 'YYYY-MM-DD HH24:MI:SS' || '''' || '),' || '''' || ' ${TIMEZONE_OFFSET}' || '''' || ')'
                WHEN DATA_TYPE_NAME IN ( 'VARCHAR', 'NVARCHAR', 'ALPHANUM', 'SHORTTEXT', 'BLOB', 'CLOB', 'NCLOB', 'TEXT' ) then '"' || COLUMN_NAME || '"'
                WHEN DATA_TYPE_NAME in ( 'VARBINARY' ) then 'TO_NVARCHAR (' || COLUMN_NAME || ')'
                ELSE '"' || COLUMN_NAME || '"'
            END AS casting,
			CASE DATA_TYPE_NAME
				WHEN 'TINYINT'		THEN 'int'
				WHEN 'SMALLINT'		THEN 'int'
				WHEN 'INTEGER' 		THEN 'int'
				WHEN 'BIGINT'		THEN 'bigint'
				WHEN 'VARCHAR'		THEN 'varchar'||'(' || TO_BIGINT(CASE WHEN COALESCE("LENGTH", 0) = 0 THEN 255 ELSE ( "LENGTH" + ROUND( "LENGTH" / 2 ) )  END) ||')'
				WHEN 'VARBINARY'	THEN 'varchar'||'(' || TO_BIGINT(CASE WHEN COALESCE("LENGTH", 0) = 0 THEN 255 ELSE ( "LENGTH" + ROUND( "LENGTH" / 2 ) )  END) ||')'
				WHEN 'NVARCHAR'		THEN 'varchar'||'(' || TO_BIGINT(CASE WHEN COALESCE("LENGTH", 0) = 0 THEN 255 ELSE ( "LENGTH" + ROUND( "LENGTH" / 2 ) )  END) ||')'
				WHEN 'CHAR'			THEN 'varchar'||'(' || TO_BIGINT(CASE WHEN COALESCE("LENGTH", 0) = 0 THEN 255 ELSE ( "LENGTH" + ROUND( "LENGTH" / 2 ) )  END) ||')'
				WHEN 'BLOB'			THEN 'varchar(65535)'
				WHEN 'CLOB'			THEN 'varchar(65535)'
				WHEN 'NCLOB'		THEN 'varchar(65535)'
				WHEN 'TEXT'			THEN 'varchar(65535)'
				WHEN 'REAL'			THEN CASE '${IS_SPECTRUM}' WHEN '1' THEN CASE '${HAS_ATHENA}' WHEN '1' THEN 'double' ELSE 'double precision' END ELSE 'double precision' END
				WHEN 'DOUBLE'		THEN CASE '${IS_SPECTRUM}' WHEN '1' THEN CASE '${HAS_ATHENA}' WHEN '1' THEN 'double' ELSE 'double precision' END ELSE 'double precision' END
                WHEN 'SMALLDECIMAL'	THEN CASE '${IS_SPECTRUM}' WHEN '1' THEN CASE '${HAS_ATHENA}' WHEN '1' THEN 'double' ELSE 'double precision' END ELSE 'double precision' END
				WHEN 'DECIMAL'		THEN CASE '${IS_SPECTRUM}' WHEN '1' THEN CASE '${HAS_ATHENA}' WHEN '1' THEN 'double' ELSE 'double precision' END ELSE 'double precision' END
				WHEN 'DATE'			THEN 'varchar(10)'
				WHEN 'TIME'			THEN 'varchar(19)'
				WHEN 'SECONDDATE'	THEN 'varchar(19)'
				WHEN 'TIMESTAMP'	THEN 'varchar(19)'
				WHEN 'BOOLEAN' 		THEN 'boolean'
			END	AS field_type,
            ( '{"name": "' || LOWER( CASE '${FIELD_HAS_PREFIX}' WHEN '1' THEN REPLACE_REGEXPR( '\/' IN REPLACE_REGEXPR( '^\W|^_' IN COLUMN_NAME WITH '' ) WITH '_' ) ELSE REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' ) END ) ||  '","type":' ||
                CASE
                	WHEN DATA_TYPE_NAME IN ( 'TINYINT', 'SMALLINT', 'INTEGER' ) THEN '["null", "int"]'
                    WHEN DATA_TYPE_NAME IN ( 'BIGINT' ) THEN '["null", "long"]'
                    WHEN DATA_TYPE_NAME IN ( 'VARCHAR', 'VARBINARY', 'NVARCHAR', 'CHAR', 'BLOB', 'CLOB', 'NCLOB', 'TEXT' ) THEN '["null", "string"]'
                    WHEN DATA_TYPE_NAME IN ( 'REAL', 'DOUBLE', 'SMALLDECIMAL', 'DECIMAL' ) THEN '["null", "double"]'
                    WHEN DATA_TYPE_NAME IN ( 'DATE', 'TIME', 'SECONDDATE', 'TIMESTAMP' ) THEN '["null", "string"]'
                	WHEN DATA_TYPE_NAME = 'BOOLEAN' THEN '["null", "boolean"]'
                end ||', "default": null}' ) AS json,
            LOWER( CASE '${FIELD_HAS_PREFIX}' WHEN '1' THEN REPLACE_REGEXPR( '\/' IN REPLACE_REGEXPR( '^\W|^_' IN COLUMN_NAME WITH '' ) WITH '_' ) ELSE REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' ) END ) AS column_name,
            0 AS column_key,
			'' AS encoding
        FROM
	    (
		SELECT
			 SCHEMA_NAME
			,TABLE_NAME
			,COLUMN_NAME
			,DATA_TYPE_NAME
			,POSITION
			,LENGTH
			,SCALE
		FROM TABLE_COLUMNS
		WHERE
		LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
		AND 
		LOWER( TABLE_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )

		UNION ALL

		SELECT
			 SCHEMA_NAME
			,VIEW_NAME AS TABLE_NAME
			,COLUMN_NAME
			,DATA_TYPE_NAME
			,POSITION
			,LENGTH
			,SCALE
		FROM VIEW_COLUMNS
		WHERE
		LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
		AND 
		LOWER( VIEW_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) ) 
	      )q
        WHERE
            LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
            and
            LOWER( TABLE_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )
            AND UPPER(COLUMN_NAME) NOT IN (${METADATA_BLACKLIST})       
        UNION ALL

        SELECT
            998 AS POSITION,
			'CONCAT( TO_CHAR( now(),' || '''' || 'YYYY-MM-DD HH24:MI:SS' || '''' || '),' || '''' || ' ${TIMEZONE_OFFSET}' || '''' || ') as etl_load_date' as fields,
            'CONCAT( TO_CHAR( now(),' || '''' || 'YYYY-MM-DD HH24:MI:SS' || '''' || '),' || '''' || ' ${TIMEZONE_OFFSET}' || '''' || ')' AS casting,
            'varchar(19)' AS field_type,
            '{"name": "etl_load_date","type":["null", "string"], "default": null}' AS json,
            'etl_load_date' AS column_name,
            0 AS column_key,
			'' AS encoding
        FROM dummy
    )x ORDER BY x.POSITION
)
