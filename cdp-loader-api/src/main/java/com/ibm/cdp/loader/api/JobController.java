package com.ibm.cdp.loader.api;

import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository.JobRunSummary;
import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.batch.service.JobLaunchService;
import com.ibm.cdp.loader.batch.service.JobLaunchService.LaunchResult;
import com.ibm.cdp.loader.batch.service.JobLaunchService.JobConflictException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * REST controller for ETL job management.
 *
 * <p>Endpoints:
 * <pre>
 * POST /api/jobs/initial   — launch initial load (202 or 409)
 * POST /api/jobs/daily     — launch daily incremental (202 or 409)
 * POST /api/jobs/monthly   — launch monthly usage (202 or 409)
 * GET  /api/jobs           — paginated job history
 * GET  /api/jobs/{runId}   — single job run details
 * GET  /api/jobs/{runId}/errors — paginated errors for a run
 * </pre>
 */
@RestController
@RequestMapping("/api/jobs")
@RequiredArgsConstructor
public class JobController {

    private final JobLaunchService launchService;
    private final EtlRecordErrorRepository errorRepo;

    @PostMapping("/initial")
    public ResponseEntity<?> launchInitial() {
        try {
            LaunchResult result = launchService.launchInitialLoad();
            return ResponseEntity.accepted().body(toResponse(result));
        } catch (JobConflictException e) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("error", e.getMessage(), "timestamp", Instant.now().toString()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Job launch failed: " + e.getMessage(),
                                 "timestamp", Instant.now().toString()));
        }
    }

    @PostMapping("/daily")
    public ResponseEntity<?> launchDaily() {
        try {
            LaunchResult result = launchService.launchDailyLoad();
            return ResponseEntity.accepted().body(toResponse(result));
        } catch (JobConflictException e) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("error", e.getMessage(), "timestamp", Instant.now().toString()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Job launch failed: " + e.getMessage(),
                                 "timestamp", Instant.now().toString()));
        }
    }

    @PostMapping("/monthly")
    public ResponseEntity<?> launchMonthly() {
        try {
            LaunchResult result = launchService.launchMonthlyLoad();
            return ResponseEntity.accepted().body(toResponse(result));
        } catch (JobConflictException e) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("error", e.getMessage(), "timestamp", Instant.now().toString()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Job launch failed: " + e.getMessage(),
                                 "timestamp", Instant.now().toString()));
        }
    }

    @GetMapping
    public ResponseEntity<?> getHistory(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size) {
        List<JobRunSummary> runs = launchService.getHistory(page, size);
        return ResponseEntity.ok(Map.of(
            "runs", runs,
            "page", page,
            "size", size
        ));
    }

    @GetMapping("/{runId}")
    public ResponseEntity<?> getByRunId(@PathVariable("runId") long runId) {
        JobRunSummary run = launchService.getByRunId(runId);
        if (run == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(run);
    }

    @GetMapping("/{runId}/errors")
    public ResponseEntity<?> getErrors(
            @PathVariable("runId") long runId,
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "50") int size) {
        var errors = errorRepo.findByRunId(runId, page, size);
        long total = errorRepo.countByRunId(runId);
        return ResponseEntity.ok(Map.of(
            "errors", errors,
            "totalCount", total,
            "page", page,
            "size", size
        ));
    }

    // =========================================================================

    private Map<String, Object> toResponse(LaunchResult r) {
        return Map.of(
            "runId",        r.runId(),
            "jobName",      r.jobName(),
            "status",       r.status(),
            "submittedAt",  r.submittedAt().toString()
        );
    }
}
