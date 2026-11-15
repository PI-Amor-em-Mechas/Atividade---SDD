# API Envios (Spring Boot + MySQL)

Requisitos: Java 17, Maven, MySQL/MariaDB.
Variáveis (opcionais): DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD.

    mvn spring-boot:run

Teste:

    curl -X POST localhost:8080/api/envios -H 'Content-Type: application/json' \
      -d '{"codigoRastreio":"BR123456789","nomeDestinatario":"Maria","ultimoStatus":"Postado"}'
    curl localhost:8080/api/envios
    curl localhost:8080/api/envios/1

Códigos: 201 criado, 200 ok, 400 validação, 404 não encontrado, 409 código duplicado.
