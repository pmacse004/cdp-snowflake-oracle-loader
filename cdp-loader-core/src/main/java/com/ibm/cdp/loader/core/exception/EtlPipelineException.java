package com.ibm.cdp.loader.core.exception;

/**
 * Thrown for unexpected infrastructure/configuration failures.
 * Not skipped — causes the job to FAIL immediately.
 */
public class EtlPipelineException extends RuntimeException {

    public EtlPipelineException(String message) {
        super(message);
    }

    public EtlPipelineException(String message, Throwable cause) {
        super(message, cause);
    }
}
