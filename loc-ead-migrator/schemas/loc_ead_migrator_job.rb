{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",

    "properties" => {

      "format" => {
        "type" => "string", "default" => "csv"
      },
      "repository" => {
        "type" => "string", "enum" => [
          "AFC",
          "MI",
          "G&M",
          "VHP",
          "RS",
          "RBSC",
          "MUS",
          "P&P",
          "MSS",
          "ALL",
          "asian",
          "eur",
          "gdc",
          "hisp",
          "lca"
        ]
      }
    }
  }
}
