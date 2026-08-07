import IndexTest from './Index.test'
import localUnitTest from './LocalUnit.test';
import coreLogicTest from './CoreLogic.test';
import sleepOverlapTest from './SleepOverlap.test';
import healthAgentTest from './HealthAgent.test';

export default function testsuite() {
  localUnitTest();
  IndexTest()
  coreLogicTest();
  sleepOverlapTest();
  healthAgentTest();
}
