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
