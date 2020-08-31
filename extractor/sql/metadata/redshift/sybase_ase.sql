select * 
from (
   SELECT
    -1 AS ordinal_position
   ,CASE
     WHEN (lower('${PARTITION_TYPE}') = 'date' OR lower('${PARTITION_TYPE}') = 'timestamp') AND (t.name not like '%date%' or t.name not like '%time%')
     THEN
      CASE upper('${PARTITION_FORMAT}')
        WHEN 'YYYY' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,4)as bigint),1900)'
     WHEN 'YYYYMM' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,6)as bigint),190001)'
     WHEN 'YYYYMMDD' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,8)as bigint),19000101)'
        WHEN 'YYYYMMDDHH' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,10)as bigint),1900010100)'
        WHEN 'YYYYMMDDHHMI' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,12)as bigint),190001010000)'
      END+' AS partition_field'
     WHEN (lower('${PARTITION_TYPE}') = 'date' OR lower('${PARTITION_TYPE}') = 'timestamp') AND (t.name like '%date%' or t.name like '%time%')
     THEN
      CASE upper('${PARTITION_FORMAT}') 
        WHEN 'YYYY' THEN 'coalesce(cast(left(convert(varchar,'+'['+c.name+']'+',112),4)as bigint),1900)'
     WHEN 'YYYYMM' THEN 'coalesce(cast(left(convert(varchar,'+'['+c.name+']'+',112),6)as bigint),190001)'
     WHEN 'YYYYMMDD' THEN 'coalesce(cast(left(convert(varchar,'+'['+c.name+']'+',112),8)as bigint),19000101)'
        WHEN 'YYYYMMDDHH' THEN 'coalesce(cast(left(str_replace(str_replace(str_replace(convert(varchar,'+'['+c.name+']'+',121),'+char(39)+'/'+char(39)+',null),'+char(39)+':'+char(39)+',null),'+char(39)+' '+char(39)+',null),10))as bigint),1900010100)'
        WHEN 'YYYYMMDDHHMI' THEN 'coalesce(cast(left(str_replace(str_replace(str_replace(convert(varchar,'+'['+c.name+']'+',121),'+char(39)+'/'+char(39)+',null),'+char(39)+':'+char(39)+',null),'+char(39)+' '+char(39)+',null),10))as bigint),1900010100)'
      END+' AS partition_field'
     WHEN lower('${PARTITION_TYPE}') = 'id' 
     THEN 'cast(((floor(coalesce(cast('+'['+c.name+']'+' as bigint),1) /  ( ${PARTITION_LENGTH} + 0.01 ) ) + 1 ) * ${PARTITION_LENGTH} ) as bigint) AS partition_field'
    END AS fields
   ,CASE
     WHEN (lower('${PARTITION_TYPE}') = 'date' OR lower('${PARTITION_TYPE}') = 'timestamp') AND (t.name not like '%date%' or t.name not like '%time%')
     THEN
      CASE upper('${PARTITION_FORMAT}') 
        WHEN 'YYYY' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,4)as bigint),1900)'
     WHEN 'YYYYMM' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,6)as bigint),190001)'
     WHEN 'YYYYMMDD' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,8)as bigint),19000101)'
        WHEN 'YYYYMMDDHH' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,10)as bigint),1900010100)'
        WHEN 'YYYYMMDDHHMI' THEN 'coalesce(cast(substring(cast('+'['+c.name+']'+' as varchar),1,12)as bigint),190001010000)'
      END+' AS partition_field'
     WHEN (lower('${PARTITION_TYPE}') = 'date' OR lower('${PARTITION_TYPE}') = 'timestamp') AND (t.name like '%date%' or t.name like '%time%')
     THEN
      CASE upper('${PARTITION_FORMAT}') 
        WHEN 'YYYY' THEN 'coalesce(cast(left(convert(varchar,'+'['+c.name+']'+',112),4)as bigint),1900)'
     WHEN 'YYYYMM' THEN 'coalesce(cast(left(convert(varchar,'+'['+c.name+']'+',112),6)as bigint),190001)'
     WHEN 'YYYYMMDD' THEN 'coalesce(cast(left(convert(varchar,'+'['+c.name+']'+',112),8)as bigint),19000101)'
        WHEN 'YYYYMMDDHH' THEN 'coalesce(cast(left(str_replace(str_replace(str_replace(convert(varchar,'+'['+c.name+']'+',121),'+char(39)+'/'+char(39)+',null),'+char(39)+':'+char(39)+',null),'+char(39)+' '+char(39)+',null),10))as bigint),1900010100)'
        WHEN 'YYYYMMDDHHMI' THEN 'coalesce(cast(left(str_replace(str_replace(str_replace(convert(varchar,'+'['+c.name+']'+',121),'+char(39)+'/'+char(39)+',null),'+char(39)+':'+char(39)+',null),'+char(39)+' '+char(39)+',null),10))as bigint),1900010100)'
      END+' AS partition_field'
     WHEN lower('${PARTITION_TYPE}') = 'id' 
     THEN 'cast(((floor(coalesce(cast('+'['+c.name+']'+' as bigint),1) /  ( ${PARTITION_LENGTH} + 0.01 ) ) + 1 ) * ${PARTITION_LENGTH} ) as bigint) AS partition_field'
    END AS casting
   ,'bigint' AS field_type
   ,'' AS json
   ,'partition_field'         AS column_name
   ,0             AS column_key
   ,'encode ${ENCODE}' AS encoding
   FROM dbo.syscolumns c 
   INNER JOIN dbo.systypes t ON c.usertype = t.usertype 
   INNER JOIN dbo.sysobjects so ON c.id = so.id
   INNER JOIN sysusers u ON so.uid = u.uid
   WHERE 1=1
   AND so.name = str_replace(str_replace(upper('${INPUT_TABLE_NAME}'),'[',null),']',null)
   AND u.name = str_replace(str_replace(upper('${INPUT_TABLE_SCHEMA}'),'[',null),']',null)
   AND c.name = str_replace(str_replace(upper('${PARTITION_FIELD}'),'[',null),']',null)
    
   UNION ALL

    SELECT 
     0 AS ordinal_position
    ,'hash(hashbytes('+char(39)+'md5'+char(39)+','+coalesce(max(tmp.fields_custom),max(tmp.fields_database))+'),'+char(39)+'md5'+char(39)+') AS custom_primary_key' as fields
    ,'hash(hashbytes('+char(39)+'md5'+char(39)+','+coalesce(max(tmp.fields_custom),max(tmp.fields_database))+'),'+char(39)+'md5'+char(39)+')' as casting
    ,'varchar(32)' AS field_type
    ,'' AS json
    ,'custom_primary_key' AS column_name
    ,1 AS column_key
    ,'encode ${ENCODE}' AS encoding
    FROM
    (
     SELECT
                 CASE WHEN index_col(o.name,i.indid,1,o.uid) is not null THEN  '['+index_col(o.name,i.indid,1,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,2,o.uid) is not null THEN ',['+index_col(o.name,i.indid,2,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,3,o.uid) is not null THEN ',['+index_col(o.name,i.indid,3,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,4,o.uid) is not null THEN ',['+index_col(o.name,i.indid,4,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,5,o.uid) is not null THEN ',['+index_col(o.name,i.indid,5,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,6,o.uid) is not null THEN ',['+index_col(o.name,i.indid,6,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,7,o.uid) is not null THEN ',['+index_col(o.name,i.indid,7,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,8,o.uid) is not null THEN ',['+index_col(o.name,i.indid,8,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,9,o.uid) is not null THEN ',['+index_col(o.name,i.indid,9,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,10,o.uid) is not null THEN ',['+index_col(o.name,i.indid,10,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,11,o.uid) is not null THEN ',['+index_col(o.name,i.indid,11,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,12,o.uid) is not null THEN ',['+index_col(o.name,i.indid,12,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,13,o.uid) is not null THEN ',['+index_col(o.name,i.indid,13,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,14,o.uid) is not null THEN ',['+index_col(o.name,i.indid,14,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,15,o.uid) is not null THEN ',['+index_col(o.name,i.indid,15,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,16,o.uid) is not null THEN ',['+index_col(o.name,i.indid,16,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,17,o.uid) is not null THEN ',['+index_col(o.name,i.indid,17,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,18,o.uid) is not null THEN ',['+index_col(o.name,i.indid,18,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,19,o.uid) is not null THEN ',['+index_col(o.name,i.indid,19,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,20,o.uid) is not null THEN ',['+index_col(o.name,i.indid,20,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,21,o.uid) is not null THEN ',['+index_col(o.name,i.indid,21,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,22,o.uid) is not null THEN ',['+index_col(o.name,i.indid,22,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,23,o.uid) is not null THEN ',['+index_col(o.name,i.indid,23,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,24,o.uid) is not null THEN ',['+index_col(o.name,i.indid,24,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,25,o.uid) is not null THEN ',['+index_col(o.name,i.indid,25,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,26,o.uid) is not null THEN ',['+index_col(o.name,i.indid,26,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,27,o.uid) is not null THEN ',['+index_col(o.name,i.indid,27,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,28,o.uid) is not null THEN ',['+index_col(o.name,i.indid,28,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,29,o.uid) is not null THEN ',['+index_col(o.name,i.indid,29,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,30,o.uid) is not null THEN ',['+index_col(o.name,i.indid,30,o.uid)+']' END +
                 CASE WHEN index_col(o.name,i.indid,31,o.uid) is not null THEN ',['+index_col(o.name,i.indid,31,o.uid)+']' END as fields_database
    ,null as fields_custom
    FROM
          sysobjects o
           INNER JOIN sysusers u
           ON o.uid = u.uid
           INNER JOIN sysindexes i
           ON o.id = i.id
    WHERE 1=1
    AND o.name = str_replace(str_replace(upper('${INPUT_TABLE_NAME}'),'[',null),']',null)
    AND u.name = str_replace(str_replace(upper('${INPUT_TABLE_SCHEMA}'),'[',null),']',null)
    AND((i.status2 & 2 = 2) OR (i.status & 2 = 2))
      UNION ALL 
    SELECT null as fields_database,case when '${CUSTOM_PRIMARY_KEY}'!='' then '${CUSTOM_PRIMARY_KEY}' else null end as fields_custom
    ) as tmp
   UNION ALL
    SELECT
    c.colid as ordinal_position,
    CASE
     WHEN t.name in ('date')     THEN 'convert(varchar,'+'['+c.name+']'+',111) AS ' + case when c.name like '%/%' then right(str_replace(c.name,'/','_'),len(c.name)-1)else c.name end
     WHEN t.name in ('datetime') THEN 'replace(convert(varchar,' +'['+c.name+']'+'121),'+char(39)+'/'+char(39)+') AS '+ case when c.name like '%/%' then right(str_replace(c.name,'/','_'),len(c.name)-1)else c.name end
     WHEN t.name in ('varchar','char','nvarchar','nchar','text') then '['+c.name+']' + ' AS ' + case when c.name like '%/%' then right(str_replace(c.name,'/','_'),len(c.name)-1)else c.name end
     WHEN t.name in ('varbinary','binary') then 'hash(['+c.name+'],'+char(39)+'md5'+char(39) + ') AS ' + case when c.name like '%/%' then right(str_replace(c.name,'/','_'),len(c.name)-1)else c.name end
     ELSE '['+c.name+']' + ' AS ' + case when c.name like '%/%' then right(str_replace(c.name,'/','_'),len(c.name)-1)else c.name end
    END AS fields,
    CASE
     WHEN t.name in ('date')     THEN 'convert(varchar,'+'['+c.name+']'+',111)'
     WHEN t.name in ('datetime') THEN 'replace(convert(varchar,' +'['+c.name+']'+'121),'+char(39)+'/'+char(39)+')'
     WHEN t.name in ('varchar','char','nvarchar','nchar','text') then '[' + c.name + ']' 
     WHEN t.name in ('varbinary','binary') then 'hash(['+c.name+'],'+char(39)+'md5'+char(39) + ')' 
     ELSE '['+c.name+']'
    END AS casting,
    CASE 
       WHEN t.name in ('bigint')                            then 'bigint'
       WHEN t.name in ('int','smallint','tinyint')          then 'int'
       WHEN t.name in ('decimal','float','numeric','real')  then 'double precision'
       WHEN t.name in ('varchar','char','nvarchar','nchar') then 'varchar('+cast(cast((c.length*0.3)+c.length as bigint) as varchar)+')'
       WHEN t.name in ('text')                              then 'varchar(65535)'
       WHEN t.name in ('varbinary','binary')                then 'varchar(32)'
       WHEN t.name in ('date')                              then 'varchar(10)'   
       WHEN t.name in ('time')                              then 'varchar(19)'
       WHEN t.name in ('datetime')                          then 'varchar(19)'
    ELSE t.name
    END as field_type,
    '' AS json,
     lower(case when c.name like '%/%' then right(str_replace(c.name,'/','_'),len(c.name)-1)else c.name end) AS column_name,
     0 AS column_key,
     'encode ${ENCODE}' AS encoding
    FROM dbo.syscolumns c 
    INNER JOIN dbo.systypes t ON c.usertype = t.usertype 
    INNER JOIN dbo.sysobjects so ON c.id = so.id
    INNER JOIN sysusers u ON so.uid = u.uid
    WHERE 1=1
    AND(c.status3 & 3) = 0 
    AND so.name = str_replace(str_replace(upper('${INPUT_TABLE_NAME}'),'[',null),']',null)
    AND u.name = str_replace(str_replace(upper('${INPUT_TABLE_SCHEMA}'),'[',null),']',null)
    AND UPPER(c.name) NOT IN (${METADATA_BLACKLIST})
   UNION ALL

    SELECT
    998 AS ordinal_position,
  'str_replace(convert(varchar,current_bigdatetime(),23),'+char(39)+'T'+char(39)+','+char(39)+' '+char(39)+') as etl_load_date' AS fields,
  'str_replace(convert(varchar,current_bigdatetime(),23),'+char(39)+'T'+char(39)+','+char(39)+' '+char(39)+') as etl_load_date' AS casting,
    'varchar(19)' AS field_type,
    '' AS json,
    'etl_load_date' AS column_name,
    0 AS column_key,
    'encode ${ENCODE}' AS encoding
) x
ORDER BY x.ordinal_position
