package com.ibm.cdp.loader.batch.support;

import org.springframework.batch.item.Chunk;
import org.springframework.batch.item.ItemWriter;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Function;

/**
 * Delegate writer that tracks the maximum (RECORD_EFFECTIVE_TS, stableId) tuple
 * seen across all chunks of a single step execution.
 *
 * <p>Because the Snowflake reader emits rows in ORDER BY RECORD_EFFECTIVE_TS, stableId
 * the last item in the last chunk is always the max. This implementation scans
 * the whole chunk to be safe against any future reordering.
 *
 * <p>Call {@link #getMaxTs()} and {@link #getMaxId()} after the step completes to
 * obtain the values to persist into ETL_WATERMARK. Both return empty if zero rows
 * were processed.
 *
 * @param <T> item type
 */
public class WatermarkCapturingWriter<T> implements ItemWriter<T> {

    private final ItemWriter<T> delegate;
    private final Function<T, OffsetDateTime> tsExtractor;
    private final Function<T, String>         idExtractor;

    /** Best (latest) watermark seen so far — null means no rows processed yet. */
    private final AtomicReference<Instant> maxTs = new AtomicReference<>(null);
    private final AtomicReference<String>  maxId = new AtomicReference<>(null);

    public WatermarkCapturingWriter(ItemWriter<T> delegate,
                                    Function<T, OffsetDateTime> tsExtractor,
                                    Function<T, String>         idExtractor) {
        this.delegate    = delegate;
        this.tsExtractor = tsExtractor;
        this.idExtractor = idExtractor;
    }

    @Override
    public void write(Chunk<? extends T> chunk) throws Exception {
        delegate.write(chunk);
        // Update watermark after a successful delegate write — never on failure.
        for (T item : chunk) {
            OffsetDateTime odt = tsExtractor.apply(item);
            String         id  = idExtractor.apply(item);
            if (odt == null) continue;
            Instant ts = odt.toInstant();
            Instant current = maxTs.get();
            if (current == null) {
                maxTs.set(ts);
                maxId.set(id);
            } else {
                int cmp = ts.compareTo(current);
                if (cmp > 0) {
                    maxTs.set(ts);
                    maxId.set(id);
                } else if (cmp == 0) {
                    // Equal timestamp — pick lexicographically greater ID for determinism
                    if (id != null && (maxId.get() == null || id.compareTo(maxId.get()) > 0)) {
                        maxId.set(id);
                    }
                }
            }
        }
    }

    /** Returns the maximum RECORD_EFFECTIVE_TS observed, or empty if no rows processed. */
    public java.util.Optional<Instant> getMaxTs() {
        return java.util.Optional.ofNullable(maxTs.get());
    }

    /** Returns the stable ID at the max timestamp, or empty if no rows processed. */
    public java.util.Optional<String> getMaxId() {
        return java.util.Optional.ofNullable(maxId.get());
    }
}
