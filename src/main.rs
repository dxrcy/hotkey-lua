use std::cell::RefCell;
use std::fs;

use mlua::{chunk, Error, Lua, Table, Value};

// use mlua::ffi::lua54::luaL_newmetatable as lua_new_metatable;

type Bindings = Vec<Binding>;

thread_local! {
    static BINDINGS: RefCell<Bindings> = const { RefCell::new(Bindings::new()) };
}

fn push_binding(binding: Binding) {
    BINDINGS.with(|bindings| {
        let mut bindings = bindings.borrow_mut();
        let bindings: &mut Bindings = bindings.as_mut();
        bindings.push(binding);
    });
}

fn with_bindings<F>(func: F)
where
    F: FnOnce(&mut Bindings) -> (),
{
    BINDINGS.with(|bindings| {
        let mut bindings = bindings.borrow_mut();
        let bindings: &mut Bindings = bindings.as_mut();
        func(bindings);
    });
}

fn main() -> mlua::Result<()> {
    let lua = Lua::new();

    let globals = lua.globals();

    lua.load(chunk! {
        Key = {}
        Key.__index = Key
        function Key.__tostring(self)
            return "<key:" .. self.keyid .. ">"
        end
    })
    .exec()?;

    create_key_global(&lua, "SUPER", "super")?;
    create_key_global(&lua, "A", "a")?;
    create_key_global(&lua, "H", "h")?;
    create_key_global(&lua, "J", "j")?;
    create_key_global(&lua, "K", "k")?;
    create_key_global(&lua, "L", "l")?;

    let bind = lua.create_function(|lua, (modifiers, keys, command)| {
        bind_func(lua, modifiers, keys, command)
    })?;
    globals.set("bind", bind)?;

    let user_file = fs::read_to_string("user.lua").expect("Failed to read file");

    lua.load(&user_file).set_name("example").exec()?;

    with_bindings(|bindings| {
        for binding in bindings {
            println!("{:?}", binding);
        }
    });

    Ok(())
}

fn create_key_global(lua: &Lua, name: &str, keyid: &str) -> mlua::Result<()> {
    let key_mt = expect_metatable(lua, "Key");
    let globals = lua.globals();

    let key = lua.create_table()?;
    key.set("keyid", keyid)?;
    key.set_metatable(Some(key_mt));

    globals.set(name, key)?;

    Ok(())
}

#[derive(Debug)]
struct Binding {
    modifiers: Vec<Key>,
    key: Key,
    command: Value,
}

#[derive(Clone, Debug)]
struct Key {
    keyid: String,
}

fn bind_func(lua: &Lua, modifiers: Table, keys: Table, command: Value) -> mlua::Result<()> {
    let modifiers = parse_key_list(lua, &modifiers);

    let key_mt = expect_metatable(lua, "Key");

    if let Some(key) = parse_key(lua, &keys) {
        bind_key(lua, modifiers, key, command)?;
    } else {
        let keys = parse_key_list(lua, &keys); // TODO(opt)
        for key in keys {
            bind_key(lua, modifiers.clone(), key, command.clone())?;
        }
    }

    Ok(())
}

fn bind_key(lua: &Lua, modifiers: Vec<Key>, key: Key, command: Value) -> mlua::Result<()> {
    println!("BIND: {:?} {:?} {:?}", modifiers, key, command);
    let binding = Binding {
        modifiers,
        key,
        command,
    };
    push_binding(binding);
    Ok(())
}

fn parse_key_list(lua: &Lua, table: &Table) -> Vec<Key> {
    let mut keys = Vec::new();

    for pair in table.pairs() {
        let (_, value): (Value, Table) = pair.expect("failed to parse table pairs");
        let key = parse_key(lua, &value).expect("Value does not have metatable `Key`");
        keys.push(key);
    }

    keys
}

fn parse_key(lua: &Lua, table: &Table) -> Option<Key> {
    let key_mt = expect_metatable(lua, "Key");

    if !is_metatable(table, &key_mt) {
        return None;
    }

    let keyid: String = table
        .get("keyid")
        .expect("table with metatable `Key` should have value `keyid` of type `String`");

    Some(Key { keyid })
}

fn is_metatable(table: &Table, metatable: &Table) -> bool {
    table.metatable().is_some_and(|mt| &mt == metatable)
}

fn expect_metatable(lua: &Lua, name: &str) -> Table {
    let metatable: Table = lua
        .globals()
        .get(name)
        .unwrap_or_else(|_| panic!("Metatable `{}` does not exist", name));
    let index: Table = metatable
        .raw_get("__index")
        .unwrap_or_else(|_| panic!("Failed to get key `{}.__index`", name));
    if index != metatable {
        panic!("Metatable `{}` is invalid", name);
    }
    metatable
}
