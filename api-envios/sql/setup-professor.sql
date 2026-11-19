-- ANTES DE EXECUTAR (MySQL 8+ / MariaDB 11+)
-- Substitua <SENHA_FORTE_AQUI> por uma senha local forte.
-- Use a mesma senha posteriormente no launcher.env.
-- Execute na sessão administrativa. Evite guardar a cópia com a senha.
CREATE DATABASE IF NOT EXISTS `amor_em_mechas`
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `amor_em_mechas`;

CREATE TABLE IF NOT EXISTS `amor_em_mechas`.`envios` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `atualizado_em` DATETIME(6) NOT NULL,
    `codigo_rastreio` VARCHAR(50) NOT NULL,
    `criado_em` DATETIME(6) NOT NULL,
    `data_atualizacao` DATETIME(6) NULL DEFAULT NULL,
    `entregue` BIT(1) NOT NULL,
    `nome_destinatario` VARCHAR(150) NOT NULL,
    `ultimo_status` VARCHAR(255) NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_envio_codigo` (`codigo_rastreio`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `amor_em_mechas`.`envio_historico` (
    `envio_id` BIGINT NOT NULL,
    `evento` VARCHAR(500) NULL DEFAULT NULL,
    `ordem` INT NOT NULL,
    PRIMARY KEY (`envio_id`, `ordem`),
    CONSTRAINT `FKllrc1qtfdi3mdnbgqwyvb00o9` FOREIGN KEY (`envio_id`)
        REFERENCES `amor_em_mechas`.`envios` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- localhost: banco e aplicação na mesma máquina.
-- VM ou servidor remoto: substitua localhost pelo host/IP de origem do cliente
-- em todas as ocorrências abaixo. Use % somente se a demonstração exigir.
-- Substitua <SENHA_FORTE_AQUI> e use a mesma senha no launcher.
-- Se a conta já existir, sua senha e seus grants anteriores são preservados.
CREATE USER IF NOT EXISTS 'rastreamento_app'@'localhost' IDENTIFIED BY '<SENHA_FORTE_AQUI>';

-- GRANTS
GRANT SELECT, INSERT, UPDATE, DELETE ON `amor_em_mechas`.`envios`
    TO 'rastreamento_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `amor_em_mechas`.`envio_historico`
    TO 'rastreamento_app'@'localhost';

-- CREATE USER e GRANT aplicam as alterações sem FLUSH PRIVILEGES.

SELECT 1;
SHOW TABLES LIKE 'envios';
SHOW TABLES LIKE 'envio_historico';
SHOW GRANTS FOR 'rastreamento_app'@'localhost';
