{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "uri" => "/managed_authorities",
    "version" => 1,
    "type" => "object",
    "properties" => {
      "uri" => {"type" => "string", "required" => false},
      "resource" => {
        "type" => "object",
        "subtype" => "ref",
        "properties" => {
          "ref" => {
            "type" => "JSONModel(:resource) uri",
            "ifmissing" => "error"
          }
        }
      },
      "subjects" => {
        "type" => "array",
        "items" => {
          "type" => "JSONModel(:subject) object",
        }
      }
    }
  }
}
