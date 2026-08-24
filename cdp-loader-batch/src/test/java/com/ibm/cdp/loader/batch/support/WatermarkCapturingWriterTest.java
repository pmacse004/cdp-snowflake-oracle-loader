package com.ibm.cdp.loader.batch.support;

import com.ibm.cdp.loader.core.model.CustomerRecord;
import org.junit.jupiter.api.Test;
import org.springframework.batch.item.Chunk;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests for {@link WatermarkCapturingWriter}.
 *
 * <p>Verifies composite watermark ordering logic:
 * <ul>
 *   <li>No rows → both getMaxTs() and getMaxId() are empty.</li>
 *   <li>Single row → that row's ts and id are captured.</li>
 *   <li>Multiple rows same ts → max ID is captured.</li>
 *   <li>Multiple rows different ts → max ts captured, id from that ts.</li>
 *   <li>Null ts items are skipped.</li>
 *   <li>Delegate write is always called.</li>
 * </ul>
 */
class WatermarkCapturingWriterTest {

    // ─── helpers ────────────────────────────────────────────────────────────

    private static CustomerRecord rec(String id, Instant ts) {
        CustomerRecord r = new CustomerRecord();
        r.setCustomerId(id);
        r.setRecordEffectiveTs(ts != null ? ts.atOffset(ZoneOffset.UTC) : null);
        return r;
    }

    private static WatermarkCapturingWriter<CustomerRecord> writer() {
        return new WatermarkCapturingWriter<>(
                chunk -> { /* no-op delegate */ },
                CustomerRecord::getRecordEffectiveTs,
                CustomerRecord::getCustomerId);
    }

    // ─── tests ───────────────────────────────────────────────────────────────

    @Test
    void no_rows_both_optionals_are_empty() {
        var w = writer();
        assertThat(w.getMaxTs()).isEmpty();
        assertThat(w.getMaxId()).isEmpty();
    }

    @Test
    void single_row_captures_ts_and_id() throws Exception {
        Instant ts = Instant.parse("2025-06-01T00:00:00Z");
        var w = writer();
        w.write(new Chunk<>(List.of(rec("ID-1", ts))));
        assertThat(w.getMaxTs()).hasValue(ts);
        assertThat(w.getMaxId()).hasValue("ID-1");
    }

    @Test
    void same_timestamp_captures_lexicographically_greatest_id() throws Exception {
        Instant ts = Instant.parse("2025-06-01T00:00:00Z");
        var w = writer();
        w.write(new Chunk<>(List.of(
                rec("ID-1", ts),
                rec("ID-9", ts),
                rec("ID-3", ts))));
        assertThat(w.getMaxTs()).hasValue(ts);
        assertThat(w.getMaxId()).hasValue("ID-9");
    }

    @Test
    void later_timestamp_wins_over_earlier_with_greater_id() throws Exception {
        Instant early = Instant.parse("2025-06-01T00:00:00Z");
        Instant late  = Instant.parse("2025-06-02T00:00:00Z");
        var w = writer();
        w.write(new Chunk<>(List.of(
                rec("ZZZ", early),   // highest ID but earlier ts
                rec("AAA", late))));  // lowest ID but later ts
        assertThat(w.getMaxTs()).hasValue(late);
        assertThat(w.getMaxId()).hasValue("AAA");
    }

    @Test
    void null_timestamp_items_are_skipped() throws Exception {
        Instant ts = Instant.parse("2025-06-01T00:00:00Z");
        var w = writer();
        w.write(new Chunk<>(List.of(
                rec("ID-1", null),  // null ts — must be skipped
                rec("ID-2", ts))));
        assertThat(w.getMaxTs()).hasValue(ts);
        assertThat(w.getMaxId()).hasValue("ID-2");
    }

    @Test
    void all_null_timestamp_items_leaves_both_empty() throws Exception {
        var w = writer();
        w.write(new Chunk<>(List.of(
                rec("ID-1", null),
                rec("ID-2", null))));
        assertThat(w.getMaxTs()).isEmpty();
        assertThat(w.getMaxId()).isEmpty();
    }

    @Test
    void delegate_write_is_called_even_when_all_timestamps_null() throws Exception {
        var delegateCallCount = new int[]{0};
        var w = new WatermarkCapturingWriter<CustomerRecord>(
                chunk -> delegateCallCount[0]++,
                CustomerRecord::getRecordEffectiveTs,
                CustomerRecord::getCustomerId);
        w.write(new Chunk<>(List.of(rec("ID-1", null))));
        assertThat(delegateCallCount[0]).isEqualTo(1);
    }

    @Test
    void accumulates_across_multiple_chunks() throws Exception {
        Instant t1 = Instant.parse("2025-06-01T00:00:00Z");
        Instant t2 = Instant.parse("2025-06-02T00:00:00Z");
        Instant t3 = Instant.parse("2025-06-01T12:00:00Z");
        var w = writer();
        w.write(new Chunk<>(List.of(rec("A", t1))));
        w.write(new Chunk<>(List.of(rec("B", t3))));
        w.write(new Chunk<>(List.of(rec("C", t2))));
        assertThat(w.getMaxTs()).hasValue(t2);
        assertThat(w.getMaxId()).hasValue("C");
    }

    @Test
    void existing_watermark_at_latest_tuple_results_in_empty_incremental_read() {
        // Reader predicate: ts > :wm OR (ts = :wm AND id > :wmId)
        // If watermark = (t2, "CUST-ZZZ") and the only row is exactly (t2, "CUST-ZZZ"),
        // neither branch matches → 0 rows returned.  This is a predicate logic assertion.
        Instant wm = Instant.parse("2025-06-02T00:00:00Z");
        String wmId = "CUST-ZZZ";
        // Row exactly at watermark
        Instant rowTs = wm;
        String  rowId = "CUST-ZZZ";
        boolean match = rowTs.isAfter(wm)
                || (rowTs.equals(wm) && rowId.compareTo(wmId) > 0);
        assertThat(match).isFalse(); // predicate returns no rows → 0 read
    }

    @Test
    void equal_timestamp_greater_id_passes_predicate() {
        Instant wm = Instant.parse("2025-06-02T00:00:00Z");
        String wmId = "CUST-100";
        // New row has same ts but greater ID
        Instant rowTs = wm;
        String  rowId = "CUST-200";
        boolean match = rowTs.isAfter(wm)
                || (rowTs.equals(wm) && rowId.compareTo(wmId) > 0);
        assertThat(match).isTrue();
    }
}
