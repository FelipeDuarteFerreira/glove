SELECT * FROM (
    SELECT
        fields,
        casting,
		field_type,
        json,
        column_name,
        column_key
    FROM (

        SELECT
            0 AS POSITION,
            CASE
            	WHEN '${CUSTOM_PRIMARY_KEY}' != '' THEN '('||REPLACE('${CUSTOM_PRIMARY_KEY}',',','||')||') AS custom_primary_key'  ELSE CONCAT( STRING_AGG( '"' || dd03l.fieldname || '"', '||' ), ' AS custom_primary_key' )
            END AS fields,
            CASE
            	WHEN '${CUSTOM_PRIMARY_KEY}' != '' THEN '('||REPLACE('${CUSTOM_PRIMARY_KEY}',',','||' )||')' ELSE STRING_AGG( '"' || dd03l.fieldname || '"', '||' )
            END AS casting,
            'varchar(255)' AS field_type,
            '' AS json,
            'custom_primary_key' AS column_name,
            1 AS column_key
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
                WHEN DATA_TYPE_NAME = 'DATE' THEN 'TO_CHAR ( ' || COLUMN_NAME || ' , ' || '''' || 'YYYY-MM-DD' ||  '''' || ') AS ' || REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' )
                WHEN DATA_TYPE_NAME IN  ( 'TIME', 'SECONDDATE', 'TIMESTAMP' ) THEN 'CONCAT( TO_CHAR ( ' || COLUMN_NAME || ' , ' || '''' || 'YYYY-MM-DD HH24:MI:SS' || '''' || '),' || '''' || ' ${TIMEZONE_OFFSET}' || '''' || ') AS ' || REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' )
                WHEN DATA_TYPE_NAME in ( 'VARCHAR', 'NVARCHAR', 'ALPHANUM', 'SHORTTEXT', 'BLOB', 'CLOB', 'NCLOB', 'TEXT' ) then '"' || COLUMN_NAME || '"' || ' as ' || REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' )
                ELSE '"' || COLUMN_NAME || '"' || ' AS ' || REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' )
            END AS fields,
            CASE
                WHEN DATA_TYPE_NAME = 'DATE' THEN 'TO_CHAR ( ' || COLUMN_NAME || ' , ' || '''' || 'YYYY-MM-DD' ||  '''' || ')'
                WHEN DATA_TYPE_NAME IN  ( 'TIME', 'SECONDDATE', 'TIMESTAMP' ) THEN 'CONCAT( TO_CHAR ( ' || COLUMN_NAME || ' , ' || '''' || 'YYYY-MM-DD HH24:MI:SS' || '''' || '),' || '''' || ' ${TIMEZONE_OFFSET}' || '''' || ')'
                WHEN DATA_TYPE_NAME IN ( 'VARCHAR', 'NVARCHAR', 'ALPHANUM', 'SHORTTEXT', 'BLOB', 'CLOB', 'NCLOB', 'TEXT' ) then '"' || COLUMN_NAME || '"'
                ELSE '"' || COLUMN_NAME || '"'
            END AS casting,
			CASE DATA_TYPE_NAME
				WHEN 'TINYINT'		THEN 'smallint'
				WHEN 'SMALLINT'		THEN 'smallint'
				WHEN 'INTEGER' 		THEN 'int'
				WHEN 'BIGINT'		THEN 'bigint'
				WHEN 'VARCHAR'		THEN 'varchar'||'(' || TO_BIGINT( round(CASE WHEN MOD("LENGTH",2) = 0 THEN "LENGTH" * ("LENGTH" / 2) else ("LENGTH" + 1) * (("LENGTH" + 1)/ 2) end, 0)) ||')'
				WHEN 'VARBINARY'	THEN 'varchar'||'(' || TO_BIGINT( round(CASE WHEN MOD("LENGTH",2) = 0 THEN "LENGTH" * ("LENGTH" / 2) else ("LENGTH" + 1) * (("LENGTH" + 1)/ 2) end, 0)) ||')'
				WHEN 'NVARCHAR'		THEN 'varchar'||'(' || TO_BIGINT( round(CASE WHEN MOD("LENGTH",2) = 0 THEN "LENGTH" * ("LENGTH" / 2) else ("LENGTH" + 1) * (("LENGTH" + 1) /2) end, 0)) ||')'
				WHEN 'CHAR'			THEN 'varchar'||'(' || TO_BIGINT( round(CASE WHEN MOD("LENGTH",2) = 0 THEN "LENGTH" * ("LENGTH" / 2) else ("LENGTH" + 1) * (("LENGTH" + 1) /2) end, 0)) ||')'
				WHEN 'BLOB'			THEN 'varchar(65535)'
				WHEN 'CLOB'			THEN 'varchar(65535)'
				WHEN 'NCLOB'		THEN 'varchar(65535)'
				WHEN 'TEXT'			THEN 'varchar(65535)'
				WHEN 'REAL'			THEN 'double precision'
				WHEN 'DOUBLE'		THEN 'double precision'
				WHEN 'DATE'			THEN 'date'
				WHEN 'TIME'			THEN 'timestamp'
				WHEN 'SECONDDATE'	THEN 'timestamp'
				WHEN 'TIMESTAMP'	THEN 'timestamp'
				WHEN 'SMALLDECIMAL'	THEN 'decimal'||'('|| "LENGTH" ||','|| "SCALE" ||')'
				WHEN 'DECIMAL'		THEN 'decimal'||'('|| "LENGTH" ||','|| "SCALE" ||')'
				WHEN 'BOOLEAN' 		THEN 'boolean'
			END	AS field_type,
            '' AS json,
            LOWER( REPLACE_REGEXPR( '\/\w+\/' IN COLUMN_NAME WITH '' ) ) AS column_name,
            0 AS column_key
        FROM
            (
        SELECT
         SCHEMA_NAME
        ,TABLE_NAME
        ,TABLE_OID
        ,COLUMN_NAME
        ,POSITION
        ,DATA_TYPE_ID
        ,DATA_TYPE_NAME
        ,OFFSET
        ,LENGTH
        ,SCALE
        ,IS_NULLABLE
        ,DEFAULT_VALUE
        ,COLLATION
        ,COMMENTS
        ,MAX_VALUE
        ,MIN_VALUE
        ,CS_DATA_TYPE_ID
        ,CS_DATA_TYPE_NAME
        ,DDIC_DATA_TYPE_ID
        ,DDIC_DATA_TYPE_NAME
        ,COMPRESSION_TYPE
        ,INDEX_TYPE
        ,COLUMN_ID
        ,PRELOAD
        ,GENERATED_ALWAYS_AS
        ,HAS_SCHEMA_FLEXIBILITY
        ,FUZZY_SEARCH_INDEX
        ,FUZZY_SEARCH_MODE
        ,MEMORY_THRESHOLD
        ,LOAD_UNIT
        ,GENERATION_TYPE
        ,IS_CACHABLE
        ,IS_CACHE_KEY
        ,ROW_ORDER_POSITION
        ,IS_HIDDEN
        ,IS_MASKED
        ,MASK_EXPRESSION
        ,CLIENTSIDE_ENCRYPTION_STATUS
        ,CLIENTSIDE_ENCRYPTION_COLUMN_KEY_ID
        ,CLIENTSIDE_ENCRYPTION_MODE
        ,PERSISTENT_MEMORY
        FROM TABLE_COLUMNS
        WHERE
         LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
        AND LOWER( TABLE_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )
        UNION ALL
        SELECT
        SCHEMA_NAME
        ,VIEW_NAME AS TABLE_NAME
        ,VIEW_OID  AS TABLE_OID
        ,COLUMN_NAME
        ,POSITION
        ,DATA_TYPE_ID
        ,DATA_TYPE_NAME
        ,OFFSET
        ,LENGTH
        ,SCALE
        ,IS_NULLABLE
        ,DEFAULT_VALUE
        ,COLLATION
        ,COMMENTS
        ,MAX_VALUE
        ,MIN_VALUE
        ,CS_DATA_TYPE_ID
        ,CS_DATA_TYPE_NAME
        ,DDIC_DATA_TYPE_ID
        ,DDIC_DATA_TYPE_NAME
        ,COMPRESSION_TYPE
        ,INDEX_TYPE
        ,COLUMN_ID
        ,PRELOAD
        ,GENERATED_ALWAYS_AS
        ,HAS_SCHEMA_FLEXIBILITY
        ,FUZZY_SEARCH_INDEX
        ,FUZZY_SEARCH_MODE
        ,MEMORY_THRESHOLD
        ,LOAD_UNIT
        ,GENERATION_TYPE
        ,IS_CACHABLE
        ,IS_CACHE_KEY
        ,ROW_ORDER_POSITION
        ,IS_HIDDEN
        ,IS_MASKED
        ,MASK_EXPRESSION
        ,CLIENTSIDE_ENCRYPTION_STATUS
        ,CLIENTSIDE_ENCRYPTION_COLUMN_KEY_ID
        ,CLIENTSIDE_ENCRYPTION_MODE
        ,PERSISTENT_MEMORY
        FROM VIEW_COLUMNS
        WHERE
         LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
        AND LOWER( VIEW_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )
        )q
        WHERE
            LOWER( SCHEMA_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_SCHEMA}', '"', '' ) )
            and
            LOWER( TABLE_NAME ) = LOWER( REPLACE( '${INPUT_TABLE_NAME}', '"', '' ) )

        UNION ALL

        SELECT
            998 AS POSITION,
			'CONCAT( TO_CHAR( now(),' || '''' || 'YYYY-MM-DD HH24:MI:SS' || '''' || '),' || '''' || ' ${TIMEZONE_OFFSET}' || '''' || ') as etl_load_date' as fields,
            'CONCAT( TO_CHAR( now(),' || '''' || 'YYYY-MM-DD HH24:MI:SS' || '''' || '),' || '''' || ' ${TIMEZONE_OFFSET}' || '''' || ')' AS casting,
            'timestamp' AS field_type,
            '' AS json,
            'etl_load_date' AS column_name,
            0 AS column_key
        FROM dummy
    )x ORDER BY x.POSITION
)
