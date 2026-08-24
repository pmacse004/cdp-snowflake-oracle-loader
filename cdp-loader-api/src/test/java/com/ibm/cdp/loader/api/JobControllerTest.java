package com.ibm.cdp.loader.api;

import com.ibm.cdp.loader.batch.repository.EtlJobRunRepository;
import com.ibm.cdp.loader.batch.repository.EtlRecordErrorRepository;
import com.ibm.cdp.loader.batch.service.JobLaunchService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Controller slice test for {@link JobController}.
 * No Oracle or Snowflake connection required — all dependencies mocked.
 */
@WebMvcTest(JobController.class)
class JobControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private JobLaunchService launchService;

    @MockBean
    private EtlRecordErrorRepository errorRepo;

    @Test
    void post_initial_returns_202() throws Exception {
        given(launchService.launchInitialLoad())
            .willReturn(new JobLaunchService.LaunchResult(42L, "INITIAL_LOAD_JOB", "STARTED", Instant.now()));

        mockMvc.perform(post("/api/jobs/initial"))
               .andExpect(status().isAccepted())
               .andExpect(jsonPath("$.runId").value(42))
               .andExpect(jsonPath("$.jobName").value("INITIAL_LOAD_JOB"))
               .andExpect(jsonPath("$.status").value("STARTED"));
    }

    @Test
    void post_initial_returns_409_when_conflict() throws Exception {
        willThrow(new JobLaunchService.JobConflictException("INITIAL job already running"))
            .given(launchService).launchInitialLoad();

        mockMvc.perform(post("/api/jobs/initial"))
               .andExpect(status().isConflict())
               .andExpect(jsonPath("$.error").exists());
    }

    @Test
    void post_daily_returns_202() throws Exception {
        given(launchService.launchDailyLoad())
            .willReturn(new JobLaunchService.LaunchResult(10L, "DAILY_INCREMENTAL_JOB", "STARTED", Instant.now()));

        mockMvc.perform(post("/api/jobs/daily"))
               .andExpect(status().isAccepted())
               .andExpect(jsonPath("$.runId").value(10));
    }

    @Test
    void post_monthly_returns_202() throws Exception {
        given(launchService.launchMonthlyLoad())
            .willReturn(new JobLaunchService.LaunchResult(20L, "MONTHLY_USAGE_JOB", "STARTED", Instant.now()));

        mockMvc.perform(post("/api/jobs/monthly"))
               .andExpect(status().isAccepted())
               .andExpect(jsonPath("$.runId").value(20));
    }

    @Test
    void get_jobs_returns_200() throws Exception {
        given(launchService.getHistory(0, 20)).willReturn(List.of());

        mockMvc.perform(get("/api/jobs?page=0&size=20"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.runs").isArray());
    }

    @Test
    void get_job_by_run_id_returns_404_when_not_found() throws Exception {
        given(launchService.getByRunId(999L)).willReturn(null);

        mockMvc.perform(get("/api/jobs/999"))
               .andExpect(status().isNotFound());
    }

    @Test
    void get_errors_for_run_returns_200() throws Exception {
        given(errorRepo.findByRunId(1L, 0, 50)).willReturn(List.of());
        given(errorRepo.countByRunId(1L)).willReturn(0L);

        mockMvc.perform(get("/api/jobs/1/errors"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.errors").isArray())
               .andExpect(jsonPath("$.totalCount").value(0));
    }
}
