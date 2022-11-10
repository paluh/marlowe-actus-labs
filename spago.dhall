{ name = "my-project"
, dependencies =
  [ "argonaut"
  , "argonaut-codecs"
  , "argonaut-generic"
  , "console"
  , "datetime"
  , "effect"
  , "either"
  , "heterogeneous"
  , "lists"
  , "maybe"
  , "newtype"
  , "prelude"
  , "profunctor"
  , "profunctor-lenses"
  , "record"
  , "typelevel-prelude"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
