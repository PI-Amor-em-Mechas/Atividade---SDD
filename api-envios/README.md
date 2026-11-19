# API Envios (Spring Boot + MySQL)

Requisitos: Java 17, Maven, MySQL/MariaDB.
Configure `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` e `DB_PASSWORD`.
O launcher seleciona o driver JDBC automaticamente. Ao iniciar o Spring
diretamente com MariaDB, defina também `DB_JDBC_VENDOR=mariadb`.
Por padrão, o módulo usa o schema `amor_em_mechas` e a conta `rastreamento_app`.
Forneça a senha externamente. Aplique a [migration manual](sql/README.md)
antes de iniciar a API. O Hibernate valida o schema existente.

    mvn spring-boot:run

Teste:

    curl -X POST localhost:8080/api/envios -H 'Content-Type: application/json' \
      -d '{"codigoRastreio":"BR123456789","nomeDestinatario":"Maria","ultimoStatus":"Postado"}'
    curl localhost:8080/api/envios
    curl localhost:8080/api/envios/1

Códigos: 201 criado, 200 ok, 400 validação, 404 não encontrado, 409 código duplicado.
