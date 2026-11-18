package com.rastreio.api.exception;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(EnvioNaoEncontradoException.class)
    public ResponseEntity<Map<String, Object>> naoEncontrado(EnvioNaoEncontradoException ex) {
        return erro(HttpStatus.NOT_FOUND, ex.getMessage(), null);
    }

    @ExceptionHandler({CodigoRastreioDuplicadoException.class, DataIntegrityViolationException.class})
    public ResponseEntity<Map<String, Object>> conflito(Exception ex) {
        String msg = ex instanceof CodigoRastreioDuplicadoException ? ex.getMessage()
                : "Violação de integridade: código de rastreio já cadastrado";
        return erro(HttpStatus.CONFLICT, msg, null);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> validacao(MethodArgumentNotValidException ex) {
        Map<String, String> campos = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(f -> campos.put(f.getField(), f.getDefaultMessage()));
        return erro(HttpStatus.BAD_REQUEST, "Dados inválidos", campos);
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
    public ResponseEntity<Map<String, Object>> requisicaoInvalida(Exception ex) {
        return erro(HttpStatus.BAD_REQUEST, "Requisição inválida", null);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> generico(Exception ex) {
        return erro(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno do servidor", null);
    }

    private ResponseEntity<Map<String, Object>> erro(HttpStatus status, String msg, Object detalhes) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", LocalDateTime.now());
        body.put("status", status.value());
        body.put("erro", status.getReasonPhrase());
        body.put("mensagem", msg);
        if (detalhes != null) body.put("campos", detalhes);
        return ResponseEntity.status(status).body(body);
    }
}
