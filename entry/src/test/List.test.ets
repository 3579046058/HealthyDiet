import IndexTest from './Index.test'
import localUnitTest from './LocalUnit.test';

export default function testsuite() {
  localUnitTest();
  IndexTest()
}