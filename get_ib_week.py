import sys
from cmsutils import cmsswIB2Week

IB = sys.argv[1]
weeknum, _ = cmsswIB2Week(IB, 0)
print("week" + str(int(weeknum)%2))
