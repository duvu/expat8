import { PassageWorker } from './passage_worker.js';

export class PassageSegmentationWorker extends PassageWorker {
  constructor({ store, pipeline, logger, maxAttempts }) {
    super({
      store,
      pipeline,
      logger,
      maxAttempts,
      claimMethod: 'claimNextPendingPassage',
      attemptField: 'attempt_count',
      logPrefix: 'passage_segmentation_worker',
      updateFailure: async (store, { passageId, retry, attemptCount, error }) => {
        await store.updatePassage({
          passageId,
          status: retry ? 'pending_segmentation' : 'failed',
          processing_error: error,
          attempt_count: attemptCount
        });
      },
      updateError: async (store, { passageId, error }) => {
        await store.updatePassage({
          passageId,
          status: 'failed',
          processing_error: `${error}`
        });
      },
      onSuccess: async (store, passage) => {
        if (typeof store.updatePassageEnrichmentStatus === 'function') {
          await store.updatePassageEnrichmentStatus({
            passageId: passage.id,
            enrichmentStatus: 'pending'
          });
        }
      }
    });
  }
}
