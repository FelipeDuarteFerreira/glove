# SFTP Extractor [![GitHub license](https://img.shields.io/github/license/dafiti/causalimpact.svg)](https://bitbucket.org/dafiti/bi_dafiti_group_nick/src/master/license)
### Extrator de dados armazenados em servidores SFTP 

## How it works

O **SFTP Extractor** permite a extração de dados de arquivos armazendos em servidores SFTP.

## Instalação

##### REQUISITOS

- Java 8 +
- Maven
- Git

##### CONSTRUÇÃO

Utilizando o [Maven](https://maven.apache.org/):

- Acesse o diretório no qual os fontes do **sftp** se localizam.
- Digite o comando _**mvn package**_.
- O arquivo **sftp.jar** será gerado no subdiretório **_target_**.

##### CONFIGURAÇÂO

* Crie um arquivo com as seguintes informações sobre seu acesso ao servidor SFTP, este será o seu **credentials file**:

```
{
	"user":"<username>",
	"password":"<password>"
}
```

## Utilização

```bash
java -jar sftp.jar  \
	--credentials=<Credentials file>  \
	--host=<SFTP Host> \
	--output=<Output path> \
	--directory=<SFTP directory> \
	--output=<Output file> \
	--path=<Temporary path to file transfer> \
	--start_date=<Start date>
	--end_date=<End date>  \
	--delimiter=<(Optional) File delimiter; ';' as default> \
	--port=<(Optional) SFTP port; 22 as default> \
	--pattern=<(Optional) SFTP file pattern; *.csv as default> \
	--partition=<(Optional)  Partition, divided by + if has more than one field> \
	--key=<(Optional) Unique key, divided by + if has more than one field>
```

## Contributing, Bugs, Questions
Contributions are more than welcome! If you want to propose new changes, fix bugs or improve something feel free to fork the repository and send us a Pull Request. You can also open new `Issues` for reporting bugs and general problems.
