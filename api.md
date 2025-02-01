# nick_prefix API
Currently this mod provides 3 global functions:
* `nick_prefix.get(name)` - returns data*
* `nick_prefix.set(name, data)` - used to set prefix for specified player
* `nick_prefix.del(name)` - used to remove prefix of specified player
* `nick_prefix.update_ntag(name)` - used to update player's nametag
  

*data is the table which can contain following:
```lua
	{
		prefix = "<prefix>",
		color = "<color>",
		pronouns = "<pronouns>",
	}
```
