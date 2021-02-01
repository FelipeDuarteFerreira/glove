
# Braze Extractor [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
### Extrator de dados armazenados em buckets do S3 

## How it works

O **Braze Extractor** permite a extração de dados da API Rest disponibilizada pela Braze.

## Instalação

##### REQUISITOS

- Java 8 +
- Maven
- Git
- Token gerado no site da braze (https://www.braze.com/docs/api/basics/#what-is-a-rest-api)

##### CONSTRUÇÃO

Utilizando o [Maven](https://maven.apache.org/):

- Acesse o diretório no qual os fontes do **braze** se localizam.
- Digite o comando _**mvn package**_.
- O arquivo **braze.jar** será gerado no subdiretório **_target_**.

##### CONFIGURAÇÂO

* Crie um arquivo com o token gerado do site da braze, este será o seu **credentials file**:

```
{
	"authorization":"<Bearer token>"
}
```

## Utilização

```bash
java -jar braze.jar  \
	--credentials=<Arquivo de credenciais>  \
	--output=<Caminho onde arquivo será salvo> \
	--type=<Tipo de extração conforme o endpoint que será extraído. As opções são: 'detail_list', 'detail' ou 'export'> \
	--service=<Nome do serviço a ser consumido, exemplo: campaigns> \
	--endpoint_list=<(Opcional) URL que retorna a lista a ser percorrida, exemplo:'https://rest.iad-03.braze.com/campaigns/list?include_archived=true&page=<<page>>' > \
	--endpoint_detail=<URL que retorna o detalhe de cada item da lista, exemplo:'https://rest.iad-03.braze.com/campaigns/details?campaign_id=<<id>>' > \
	--field=<Campos que serão gerados no arquivo de saída> \
	--partition=<(Opcional) Partição, dividos por + quando for mais de um> \	
	--key=<(Opcional) Chave única, dividos por + quando for mais de um> \
	--sleep=<(Opcional) Tempo de espera entre uma chamada de outra. '0' é o padrão> \
	--request_body=<(Opcional) Parâmetro JSON que deve ser utilizado com o type 'export'>
```

## Exemplos

##### Exemplo de tipo 'list detail' (Padrão)

```bash
java -jar /<path>/braze.jar \
  --credentials="<path>/<credentials.json>" \
  --output="<output_path>/<file_name.csv>" \
  --service="campaigns" \
  --endpoint_list="https://rest.iad-03.braze.com/campaigns/list?include_archived=true&page=<<page>>" \
  --endpoint_detail="https://rest.iad-03.braze.com/campaigns/details?campaign_id=<<id>>" \
  --field="created_at+updated_at+id+name+archived+draft+schedule_type+channels+first_sent+last_sent+tags+messages+conversion_behaviors" \
  --partition="::fixed(FULL)" \
  --key="id"
```

##### Exemplo de tipo 'detail'

```bash
java -jar /<path>/braze.jar \
  --credentials="<path>/<credentials.json>" \
  --output="<output_path>/<file_name.csv>" \
  --service="data" \
  --type="detail" \
  --endpoint_detail="https://rest.iad-03.braze.com/kpi/uninstalls/data_series?length=30&ending_at=${ENDDATE}T00%3A00%3A00" \
  --field="time+uninstalls" \
  --partition="::dateformat(time,yyyy-MM-dd,yyyy)" \
  --key="::md5([[time]])"
```

##### Exemplo de tipo 'export'

```bash
java -jar /<path>/braze.jar \
  --credentials="<path>/<credentials.json>" \
  --output="<output_path>/<file_name.csv>" \
  --service="users" \
  --type="export" \
  --endpoint_detail="https://rest.iad-03.braze.com/users/export/segment" \
  --field="country::jsonpath(content, $.country, false)+braze_id::jsonpath(content, $.braze_id, false)+external_id::jsonpath(content, $.external_id, false)+random_bucket::jsonpath(content, $.random_bucket, false)" \
  --partition="::fixed(FULL)" \
  --key="::checksum()" \
  --request_body='{"segment_id":"<segment_id>","callback_endpoint":"https://rest.iad-03.braze.com/users/export/segment/callback/","fields_to_export":["country","external_id","braze_id","random_bucket"]}' \
  --sleep=25
```

## Contributing, Bugs, Questions
Contributions are more than welcome! If you want to propose new changes, fix bugs or improve something feel free to fork the repository and send us a Pull Request. You can also open new `Issues` for reporting bugs and general problems.
