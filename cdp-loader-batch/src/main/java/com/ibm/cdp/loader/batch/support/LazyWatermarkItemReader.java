package com.ibm.cdp.loader.batch.support;

import org.springframework.batch.item.ExecutionContext;
import org.springframework.batch.item.ItemStreamException;
import org.springframework.batch.item.ItemStreamReader;
import org.springframework.batch.item.database.JdbcCursorItemReader;

import java.util.function.Supplier;

/**
 * Lazily-built {@link ItemStreamReader} that defers construction of the underlying
 * {@link JdbcCursorItemReader} until {@link #open(ExecutionContext)} is called.
 *
 * <p>This allows the watermark to be read from Oracle <em>at step-execution time</em>
 * rather than at application-context startup, which is the normal lifecycle for
 * non-step-scoped {@code @Bean} methods in a {@link org.springframework.context.annotation.Configuration} class.
 *
 * @param <T> item type
 */
public class LazyWatermarkItemReader<T> implements ItemStreamReader<T> {

    private final Supplier<JdbcCursorItemReader<T>> readerFactory;
    private JdbcCursorItemReader<T> delegate;

    public LazyWatermarkItemReader(Supplier<JdbcCursorItemReader<T>> readerFactory) {
        this.readerFactory = readerFactory;
    }

    @Override
    public void open(ExecutionContext executionContext) throws ItemStreamException {
        // Build the real reader here — watermark is read from Oracle at this point
        delegate = readerFactory.get();
        delegate.open(executionContext);
    }

    @Override
    public T read() throws Exception {
        return delegate.read();
    }

    @Override
    public void update(ExecutionContext executionContext) throws ItemStreamException {
        if (delegate != null) delegate.update(executionContext);
    }

    @Override
    public void close() throws ItemStreamException {
        if (delegate != null) delegate.close();
    }
}
