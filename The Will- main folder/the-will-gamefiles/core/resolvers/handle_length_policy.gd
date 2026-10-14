extends RefCounted

# Reference-character Forge authoring bands, measured along the handle axis.
# Anatomical hand footprints and reach remain separate runtime constraints.
const MIN_HANDLE_LENGTH_METERS := 0.100
const TWO_HAND_LENGTH_METERS := 0.200
const LONG_HANDLE_LENGTH_METERS := 0.250
const BOUNDARY_EPSILON_METERS := 0.0000001

const BAND_INVALID := &"invalid"
const BAND_SINGLE_HAND := &"single_hand"
const BAND_TWO_HAND := &"two_hand"
const BAND_LONG_HANDLE := &"long_handle"


static func classify_length(span_meters: float) -> StringName:
	if not is_finite(span_meters) or span_meters + BOUNDARY_EPSILON_METERS < MIN_HANDLE_LENGTH_METERS:
		return BAND_INVALID
	if span_meters + BOUNDARY_EPSILON_METERS < TWO_HAND_LENGTH_METERS:
		return BAND_SINGLE_HAND
	if span_meters + BOUNDARY_EPSILON_METERS < LONG_HANDLE_LENGTH_METERS:
		return BAND_TWO_HAND
	return BAND_LONG_HANDLE


static func meets_minimum(span_meters: float) -> bool:
	return classify_length(span_meters) != BAND_INVALID


static func allows_two_hands(span_meters: float) -> bool:
	return classify_length(span_meters) in [BAND_TWO_HAND, BAND_LONG_HANDLE]
