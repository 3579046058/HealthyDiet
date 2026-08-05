import IndexTest from './Index.test'
import localUnitTest from './LocalUnit.test';
import coreLogicTest from './CoreLogic.test';

export default function testsuite() {
  localUnitTest();
  IndexTest()
  coreLogicTest();
}