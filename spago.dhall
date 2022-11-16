{ name = "my-project"
, dependencies =
  [ "argonaut"
  , "argonaut-codecs"
  , "argonaut-generic"
  , "arrays"
  , "console"
  , "control"
  , "datetime"
  , "debug"
  , "effect"
  , "either"
  , "enums"
  , "exceptions"
  , "foldable-traversable"
  , "heterogeneous"
  , "integers"
  , "lists"
  , "marlowe"
  , "maybe"
  , "newtype"
  , "numbers"
  , "ordered-collections"
  , "orders"
  , "prelude"
  , "profunctor"
  , "profunctor-lenses"
  , "record"
  , "refined"
  , "strings"
  , "transformers"
  , "tuples"
  , "typelevel-prelude"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
