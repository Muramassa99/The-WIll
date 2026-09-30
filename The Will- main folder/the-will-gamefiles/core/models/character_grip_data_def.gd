extends Resource

## Runtime association of an already prepared character and its approved
## contact-envelope settings. Loading this Resource never measures or saves.
@export var character_id: StringName = StringName()
@export var anatomy: Resource
@export var contact_config: Dictionary = {}
