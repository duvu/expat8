/**
 * Runs `work` inside a transaction when the pool can hand out clients;
 * plain query-only pools (test doubles) run it directly against the pool.
 */
export async function withOptionalTransaction({ pool, logger }, work) {
  if (typeof pool.connect !== 'function') {
    return work(pool);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error?.('db_transaction_failed', { error });
    throw error;
  } finally {
    client.release();
  }
}
