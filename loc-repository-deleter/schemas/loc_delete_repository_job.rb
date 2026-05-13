{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",

    "properties" => {

      "repository" => {
        "type" => "string", "ifmissing" => "error"
      },
      "secret" => {
        "type" => "string", "ifmissing" => "error"
      },
    }
  }
}
