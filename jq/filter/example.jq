. as $context
| to_entries
| group_by(.value.color)
| map({
  key: (.[0].value.color),
  value: map(.value.name)
})
| from_entries
