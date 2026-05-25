import { PassageWorker } from './passage_worker.js';

export class PassageEnrichmentWorker extends PassageWorker {
  constructor({ store, pipeline, logger, maxAttempts }) {
    super({
      store,
      pipeline,
      logger,
      maxAttempts,
      claimMethod: 'claimNextPendingEnrichment',
      attemptField: 'enrichment_attempt_count',
      logPrefix: 'passage_enrichment_worker',
      updateFailure: async (store, { passageId, retry, attemptCount }) => {
        await store.updatePassageEnrichmentStatus({
          passageId,
          enrichmentStatus: retry ? 'pending' : 'failed',
          enrichment_attempt_count: attemptCount
        });
      },
      updateError: async (store, { passageId }) => {
        await store.updatePassageEnrichmentStatus({ passageId, enrichmentStatus: 'failed' });
      }
    });
  }
}
