class_name StarCalc
extends RefCounted

## leaks <= stage leak_limit, 0 = not a win.


static func star_for(leaks: int, leak_limit: int) -> int:
	if leaks == 0:
		return 3
	if leaks <= 2:
		return 2
	if leaks <= leak_limit:
		return 1
	return 0
