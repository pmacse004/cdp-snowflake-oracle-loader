package com.ibm.cdp.loader.core.validation;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

import java.util.List;

/**
 * Immutable result of a record validation pass.
 */
@Getter
@RequiredArgsConstructor
public class ValidationResult {

    private final boolean valid;
    private final String errorCode;
    private final String errorMessage;

    public static ValidationResult ok() {
        return new ValidationResult(true, null, null);
    }

    public static ValidationResult fail(String errorCode, String errorMessage) {
        return new ValidationResult(false, errorCode, errorMessage);
    }

    @Override
    public String toString() {
        return valid ? "VALID" : "[" + errorCode + "] " + errorMessage;
    }
}
