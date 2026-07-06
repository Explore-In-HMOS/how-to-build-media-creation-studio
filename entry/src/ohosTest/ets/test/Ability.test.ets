import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    beforeAll(() => {
    })
    beforeEach(() => {
    })
    afterEach(() => {
    })
    afterAll(() => {
    })
    it('assertEqual', 0, () => {
      hilog.info(0x0000, 'testTag', '%{public}s', 'it begin');
      const title = 'Media Creation Studio';
      expect(title).assertEqual('Media Creation Studio');
    })
  })
}
