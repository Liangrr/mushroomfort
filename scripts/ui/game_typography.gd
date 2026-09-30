class_name GameTypography
extends RefCounted

## 1.5× close-view PC/mobile type scale for the 1280x720 design canvas.
## Essential gameplay text stays at or above BODY; smaller roles are reserved
## for short, high-contrast secondary metadata.
## The bottom readability tier receives the requested 20% increase without
## changing body, heading, or display hierarchy. Values are rounded to the
## nearest rendered pixel.
const SMALL_TEXT_MAX := 18
const SMALL_TEXT_SCALE := 1.20
const CAPTION := 20
const MICRO_LABEL := 22
const STATUS := 20
const BADGE := 21
const DETAIL := 24
const BODY := 27
const ACTION := 30
const DENSE_HEADING := 30
const SECTION_HEADING := 36
const DISPLAY := 42
const SCREEN_TITLE := 48
const RESULT_DISPLAY := 54


static func raised_small_text(size: int) -> int:
	if size > SMALL_TEXT_MAX:
		return size
	return roundi(float(size) * SMALL_TEXT_SCALE)
