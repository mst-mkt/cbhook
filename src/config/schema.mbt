///|
priv struct Schema[T] {
  decode : (Json, String) -> Result[T, Array[String]]
  to_schema : () -> Json
}

///|
priv struct Field[T] {
  name : String
  required : Bool
  prop_schema : () -> Json
  extract : (Map[String, Json], String) -> Result[T, Array[String]]
}

///|
priv struct ObjSchema[F] {
  fields : Array[(String, Bool, () -> Json)]
  decode : (Map[String, Json], String) -> Result[F, Array[String]]
}

///|
fn jobj(entries : Array[(String, Json)]) -> Json {
  Map::from_array(entries).to_json()
}

///|
fn join_with(items : Array[String], sep : String) -> String {
  match items {
    [] => ""
    [head, .. tail] => tail.fold(init=head, fn(acc, x) { acc + sep + x })
  }
}

///|
fn[T] errs(r : Result[T, Array[String]]) -> Array[String] {
  match r {
    Ok(_) => []
    Err(e) => e
  }
}

///|
fn combine(parts : Array[Array[String]]) -> Array[String] {
  parts.fold(init=[], fn(acc, p) { [..acc, ..p] })
}

///|
fn[T] sequence(
  rs : Array[Result[T, Array[String]]],
) -> Result[Array[T], Array[String]] {
  rs.fold(init=Ok([]), fn(acc, r) {
    match (acc, r) {
      (Ok(xs), Ok(x)) => Ok([..xs, x])
      _ => Err(combine([errs(acc), errs(r)]))
    }
  })
}

///|
fn expect_object(
  json : Json,
  ctx : String,
) -> Result[Map[String, Json], Array[String]] {
  match json {
    Object(obj) => Ok(obj)
    _ => Err(["\{ctx}: expected an object"])
  }
}

///|
fn unknown_errors(
  obj : Map[String, Json],
  allowed : Array[String],
  ctx : String,
) -> Array[String] {
  obj
  .keys()
  .fold(init=[], fn(acc, k) {
    if allowed.contains(k) {
      acc
    } else {
      [..acc, "\{ctx}: unknown field \"\{k}\""]
    }
  })
}

///|
fn string_schema() -> Schema[String] {
  {
    decode: (json, ctx) => match json {
      String(s) => Ok(s)
      _ => Err(["\{ctx}: expected a string"])
    },
    to_schema: () => jobj([("type", "string".to_json())]),
  }
}

///|
fn int_schema(minimum? : Int) -> Schema[Int] {
  {
    decode: (json, ctx) => match json {
      Number(n, ..) => {
        let i = n.to_int()
        let es = combine([
          if i.to_double() != n { ["\{ctx}: expected an integer"] } else { [] },
          if minimum is Some(min) && i < min {
            ["\{ctx}: expected >= \{min}"]
          } else {
            []
          },
        ])
        if es.is_empty() {
          Ok(i)
        } else {
          Err(es)
        }
      }
      _ => Err(["\{ctx}: expected a number"])
    },
    to_schema: () => {
      let base : Array[(String, Json)] = [("type", "integer".to_json())]
      match minimum {
        Some(min) => jobj([..base, ("minimum", min.to_json())])
        None => jobj(base)
      }
    },
  }
}

///|
fn[T] enum_schema(choices : Array[String], of : (String) -> T?) -> Schema[T] {
  {
    decode: (json, ctx) => match json {
      String(s) =>
        match of(s) {
          Some(v) => Ok(v)
          None =>
            Err([
              "\{ctx}: expected one of \{join_with(choices, ", ")}, got \"\{s}\"",
            ])
        }
      _ => Err(["\{ctx}: expected a string"])
    },
    to_schema: () => jobj([("enum", choices.to_json())]),
  }
}

///|
fn[T] array_schema(item : Schema[T], min_items~ : Int = 0) -> Schema[Array[T]] {
  {
    decode: (json, ctx) => match json {
      Array(a) => {
        let min_err = if a.length() < min_items {
          ["\{ctx}: expected at least \{min_items} item(s)"]
        } else {
          []
        }
        let results = a.mapi((i, j) => (item.decode)(j, "\{ctx}[\{i}]"))
        match sequence(results) {
          Ok(vs) if min_err.is_empty() => Ok(vs)
          r => Err(combine([min_err, errs(r)]))
        }
      }
      _ => Err(["\{ctx}: expected an array"])
    },
    to_schema: () => {
      let base : Array[(String, Json)] = [
        ("type", "array".to_json()),
        ("items", (item.to_schema)()),
      ]
      if min_items > 0 {
        jobj([..base, ("minItems", min_items.to_json())])
      } else {
        jobj(base)
      }
    },
  }
}

///|
fn[T] required_field(name : String, schema : Schema[T]) -> Field[T] {
  {
    name,
    required: true,
    prop_schema: schema.to_schema,
    extract: (obj, ctx) => match obj.get(name) {
      Some(j) => (schema.decode)(j, "\{ctx}.\{name}")
      None => Err(["\{ctx}: missing required field \"\{name}\""])
    },
  }
}

///|
fn[T] optional_field(name : String, schema : Schema[T]) -> Field[T?] {
  {
    name,
    required: false,
    prop_schema: schema.to_schema,
    extract: (obj, ctx) => match obj.get(name) {
      Some(j) =>
        match (schema.decode)(j, "\{ctx}.\{name}") {
          Ok(v) => Ok(Some(v))
          Err(e) => Err(e)
        }
      None => Ok(None)
    },
  }
}

///|
fn const_field(name : String, value : String) -> Field[Unit] {
  {
    name,
    required: true,
    prop_schema: () => jobj([("const", value.to_json())]),
    extract: (obj, ctx) => match obj.get(name) {
      Some(String(s)) =>
        if s == value {
          Ok(())
        } else {
          Err(["\{ctx}.\{name}: expected \"\{value}\", got \"\{s}\""])
        }
      Some(_) => Err(["\{ctx}.\{name}: expected \"\{value}\""])
      None => Err(["\{ctx}: missing required field \"\{name}\""])
    },
  }
}

///|
fn object_schema_json(fields : Array[(String, Bool, () -> Json)]) -> Json {
  let props = fields.map(fn(f) { (f.0, (f.2)()) })
  let required = fields.filter(fn(f) { f.1 }).map(fn(f) { f.0 })
  jobj([
    ("type", "object".to_json()),
    ("additionalProperties", false.to_json()),
    ("required", required.to_json()),
    ("properties", jobj(props)),
  ])
}

///|
fn[F] pure(f : F) -> ObjSchema[F] {
  { fields: [], decode: (_obj, _ctx) => Ok(f) }
}

///|
fn[A, B] ObjSchema::apply(
  self : ObjSchema[(A) -> B],
  fld : Field[A],
) -> ObjSchema[B] {
  {
    fields: [..self.fields, (fld.name, fld.required, fld.prop_schema)],
    decode: (obj, ctx) => {
      let rf = (self.decode)(obj, ctx)
      let ra = (fld.extract)(obj, ctx)
      match (rf, ra) {
        (Ok(g), Ok(a)) => Ok(g(a))
        _ => Err(combine([errs(rf), errs(ra)]))
      }
    },
  }
}

///|
fn[T] ObjSchema::build(self : ObjSchema[T]) -> Schema[T] {
  {
    decode: (json, ctx) => match expect_object(json, ctx) {
      Err(e) => Err(e)
      Ok(obj) => {
        let names = self.fields.map(fn(f) { f.0 })
        let unknown = unknown_errors(obj, names, ctx)
        match (self.decode)(obj, ctx) {
          Ok(v) if unknown.is_empty() => Ok(v)
          r => Err(combine([unknown, errs(r)]))
        }
      }
    },
    to_schema: () => object_schema_json(self.fields),
  }
}

///|
fn[T] tagged(tag : String, variants : Array[(String, Schema[T])]) -> Schema[T] {
  {
    decode: (json, ctx) => match expect_object(json, ctx) {
      Err(e) => Err(e)
      Ok(obj) =>
        match obj.get(tag) {
          Some(String(s)) => {
            let matched : Schema[T]? = variants.fold(init=None, fn(acc, v) {
              match acc {
                Some(_) => acc
                None => if v.0 == s { Some(v.1) } else { None }
              }
            })
            match matched {
              Some(variant) => (variant.decode)(json, ctx)
              None => {
                let known = variants.map(fn(v) { v.0 })
                Err([
                  "\{ctx}.\{tag}: unknown value \"\{s}\" (expected one of \{join_with(known, ", ")})",
                ])
              }
            }
          }
          Some(_) => Err(["\{ctx}.\{tag}: expected a string"])
          None => Err(["\{ctx}: missing required field \"\{tag}\""])
        }
    },
    to_schema: () =>
      jobj([("oneOf", variants.map(fn(v) { (v.1.to_schema)() }).to_json())]),
  }
}
