package com.ibm.cdp.loader.core.exception;

/**
 * Thrown when a source record fails validation.
 * Caught by Spring Batch skip policy — causes the record to be logged to
 * ETL_RECORD_ERROR and counted as rejected, but processing continues.
 */
public class RecordValidationException extends RuntimeException {

    private final String errorCode;
    private final String sourceRecordId;

    public RecordValidationException(String errorCode, String message, String sourceRecordId) {
        super(message);
        this.errorCode = errorCode;
        this.sourceRecordId = sourceRecordId;
    }

    public String getErrorCode() {
        return errorCode;
    }

    public String getSourceRecordId() {
        return sourceRecordId;
    }
}
