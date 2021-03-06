

# SimilarWeb API Extractor
### Extrator de dados da API SimilarWeb.

## How it works

O SimilarWeb API Extractor possibilita a extração de dados para análise dos concorrentes, fornecendo insights para tomar decisões de marketing e negócios fornecidos pela SimilarWeb API. A documentação dos endpoints e campos estão disponíveis neste documento: https://documenter.getpostman.com/view/5388671/RzfcNs8W

## Instalação

##### REQUISITOS

- Java 8 +
- Maven
- Git

##### CONSTRUÇÃO

Utilizando o [Maven](https://maven.apache.org/):

- Acesse o diretório no qual os fontes do **similarweb** se localizam.
- Digite o comando _**mvn package**_.
- O arquivo **similarweb.jar** será gerado no subdiretório **_target_**.

##### CONFIGURAÇÃO

* Crie um arquivo com as chaves fornecidas pela API SimilarWeb, este será o seu **credentials file**:

```
{
	"api_key":"<apiKey>"
}
```

## Utilização

```bash
java -jar similarweb.jar  \
	--credentials=<Arquivo com as credenciais> \
	--output=<Caminho onde o arquivo será salvo> \
	--field=<Campos que serão gerados no arquivo de saída> \
	--endpoint=<Endpoint que será extraído, exemplo: "/v1/website/bbc.com/traffic-sources/paid-search"> \
	--object=<Objeto JSON, exemplo: "search"> \
	--parameters=<(Opcional) JSON com os parâmetros, exemplo: {"country":"br","start_date":"2021-01","end_date":"2021-03"}> \
	--partition=<(Opcional) Partição, dividos por + quando for mais de um> \
	--key=<(Opcional) Chave única, dividos por + quando for mais de um>

```

##### EXEMPLO 1
Seguindo a documentação da SimilarWeb API, podemos dar o exemplo de extração do endpoint **total-traffic-and-engagement/visits**, extraindo a data e o total de visitas.

```javascript
{
  "meta": {
    "request": {
      "granularity": "Monthly",
      "main_domain_only": false,
      ...
    },
    "status": "Success",
    "last_updated": "2019-02-28"
  },
  "visits": [
    {
      "date": "2020-01-01",
      "visits": 41271116.47334743
    },
    {
      "date": "2020-01-02",
      "visits": 40004165.63111901
    },
    ...
  ]
}
```
A configuração ficaria assim:

```bash
java -jar similarweb.jar \
	--credentials="/home/etl/credentials/similarweb.json" \
	--output="/tmp/similarweb/visits/visits.csv" \
	--endpoint="v1/website/bbc.com/total-traffic-and-engagement/visits" \
	--field="date+visits" \
	--parameters='{"country":"br", "start_date":"2020-01", "end_date":"2020-12"}' \
	--object="visits" \
	--partition="::dateformat(date,yyyy-MM-dd,yyyyMM)" \
	--key='::checksum()'
```

##### EXEMPLO 2
Em algumas situações é necessário utilizar configurações avançadas para extrair os dados corretamente. Considerando o endpoint **mobile-traffic-sources/search-visits-distribution**, é necessário que sejam passados parâmetros para o endpoint e, posteriormente, selecionados valores aninhados no JSON retornado pela API, como é o caso dos dados de **visits_distribution**:

```javascript
"data": [
{
  "date": "2020-01-01",
  "total_search_visits": 7575103.407615022,
  "visits_distribution": {
    "organic_branded_visits": 3364970.517540759,
    "organic_non_branded_visits": 4209803.087022769,
    ...
  }
},
{
  "date": "2020-02-01",
  "total_search_visits": 5836514.765391576,
  "visits_distribution": {
    "organic_branded_visits": 2461524.9469057536,
    "organic_non_branded_visits": 3374446.7815971067,
    ...
  }
}
```

Nessa situação a configuração ficaria assim:

```bash
java -jar similarweb.jar \
	--credentials="/home/etl/credentials/similarweb.json" \
	--output="/tmp/similarweb/mts/search_visits_distribution.csv" \
	--endpoint="/v1/website/bbc.com/mobile-traffic-sources/search-visits-distribution" \
	--field="date+total_search_visits+visits_distribution.organic_branded_visits" \
	--parameters='{"country":"br", "start_date":"2020-01", "end_date":"2020-12"}' \
	--object="data" \
	--partition="::dateformat(date,yyyy-MM-dd,yyyyMM)" \
	--key='::checksum()'
```

Para recuperar campos aninhados no JSON de retorno é necessário utilizar a sintaxe do JSONPath, ou seja, montando o caminho dos campos separados por ponto: Ex.: **visits_distribution.organic_branded_visits**

##### EXEMPLO 3
Como pode ser observado, qualquer parâmetro pode ser fornecido para API por meio do parâmetro **parameters** do extrator, que, como pode ser observado, recebe um JSON contendo os parâmetros desejados. 

Em outras situações, como no caso do endpoint **total-traffic-and-engagement/visits-split**, o object (ou lista contendo os valores desejados) não é disponibilizado no JSON:

```javascript
{
  "meta": {
    "request": {
      "granularity": "Monthly",
      "main_domain_only": false,
      ...
    },
    "status": "Success",
    "last_updated": "2019-02-28"
  },
  "desktop_visit_share": 0.3567780202168426,
  "mobile_web_visit_share": 0.6432219797831574
}
```

Neste caso, deve ser informado o valor * no parâmetro **object** do extrator:

```bash
java -jar similarweb.jar \
	--credentials="/home/etl/credentials/similarweb.json" \
	--output="/tmp/similarweb/total_traffic/visits_split.csv" \
	--endpoint="v1/website/bbc.com/total-traffic-and-engagement/visits-split" \
	--field="desktop_visit_share+mobile_web_visit_share" \
	--parameters='{"country":"br"}' \
	--object="*"
```

> Não é possível extrair dados de endpoint que recebam ID como parâmetro diretamente no nome.

##### EXEMPLO 4
Pegando o endpoint **traffic-sources/overview-share** como exemplo, que contém um formato um pouco diferente de json:

```javascript
{
  "meta": {
    "request": {
      "granularity": "Monthly",
      ...
    },
    "status": "Success",
    "last_updated": "2019-02-28"
  },
  "visits": {
    "bbc.com": [
      {
        "source_type": "Search",
        "visits": [
          {
            "date": "2017-11-01",
            "organic": 1684411.973757629,
            "paid": 5098.656956320019
          },
          {
            "date": "2017-12-01",
            "organic": 1744108.1481261088,
            "paid": 3939.4573192256294
          },
          ...
        ]
      },
      {
        "source_type": "Social",
        "visits": [
          {
            "date": "2017-11-01",
            "organic": 1175749.3938003941,
            "paid": 0
          },
          {
            "date": "2017-12-01",
            "organic": 1248981.2556664492,
            "paid": 0
          },
          ...
        ]
      },
      ...
    ]
  }
}
```

Nesse caso, para conseguirmos pegar os dados de **source_type**, **date** e **organic**, precisamos informar de uma maneira um pouco diferente o parâmetros field e object:

```bash
java -jar similarweb.jar \
  --credentials="/home/etl/credentials/similarweb.json" \
  --output="/tmp/similarweb/desktop_traffic_sources_overview/desktop_traffic_sources_overview.csv" \
  --endpoint="/v1/website/bbc.com/traffic-sources/overview-share" \
  --field="source_type+visits[index].date+visits[index].organic" \
  --parameters='{"country":"br","granularity":"daily"}' \
  --object="visits.['bbc.com']" 
```

Como vamos pegar o **date** que está dentro de **visits** que contém vários arrays, temos que obrigatoriamente informar o campo dessa maneira: visits[index].date


## Contributing, Bugs, Questions
Contributions are more than welcome! If you want to propose new changes, fix bugs or improve something feel free to fork the repository and send us a Pull Request. You can also open new `Issues` for reporting bugs and general problems.