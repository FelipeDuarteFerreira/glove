SELECT 
	${TABLE_FIELD_LIST}, 
	${DELTA_FIELD_CASTING} as delta_field
FROM 
   [${INPUT_TABLE_SCHEMA}].[${INPUT_TABLE_NAME}] noholdlock
WHERE 
	${WHERE_CONDITION_TO_DELTA}