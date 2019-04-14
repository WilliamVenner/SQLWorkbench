# SQLWorkbench

This tool is an in-game SQLite & MySQL database interface for Garry's Mod.

Using this tool, you can manage your server's local SQLite database (`garrysmod/sv.db`) and any remote MySQL databases you desire to connect to.

## Requirements

**Only super admins can use SQLWorkbench. All net messages sent by non-super-admins are discarded for your security.**

To connect to MySQL databases, your server must have the [MySQLOO module](https://github.com/FredyH/MySQLOO) installed.

## Usage

To open the menu, first make sure you are a super admin, and then either:

* Type `!sqlworkbench` in chat
* Type `sqlworkbench` in your game's console

## Features

* Interface with remote MySQL servers
* Interface with server's local SQLite database
* Execute SQL queries
* SQL beautifier
* SQL syntax highlighting
* Basic live SQL autocompletion
* Supports multiple simultaneous MySQL connections
* Tabbed view of each connection
* View results of SQL queries
* All actions are logged to the server's console
* Automatic presets for `SELECT`, `UPDATE`, `DELETE` and `INSERT` statements
* MySQL passwords are Vernam-cipher encrypted before being sent to the server
* MySQL password field is masked unless hovered
* Shows query execution times
* Menu can be minimized and opened in the same state later on
* `CREATE TABLE` statement retrieval
* Icon differentiation for empty tables and populated tables
* Table row deletion
* Table row updating
* Table deletion
* Table emptying
* Internally uses prepared statements and appropriate escaping to prevent SQL injection
* Discards net messages sent by non-super-admins to prevent exploitation
* Discards net messages sent by players who do not have the SQLWorkbench menu open to prevent exploitation
* Menu elements can be dragged and sized to your liking
* Primary key columns are highlighted in yellow
* Uses the Ace embedded code editor, and works offline without a need for JavaScript CDNs

## Screenshots

![](http://i.venner.io/gmod_2019-04-14_21-10-44.png)

![](http://i.venner.io/PaintDotNet_2019-04-14_21-21-19.png)

![](http://i.venner.io/gmod_2019-04-14_21-35-15.png)

![](http://i.venner.io/gmod_2019-04-14_21-46-22.png)

![](http://i.venner.io/gmod_2019-04-14_21-16-21.png)

![](http://i.venner.io/gmod_2019-04-14_21-19-02.png)

![](http://i.venner.io/gmod_2019-04-14_21-48-47.png)

## License

This software is licensed under the [MIT License](https://github.com/WilliamVenner/SQLWorkbench/blob/master/LICENSE)