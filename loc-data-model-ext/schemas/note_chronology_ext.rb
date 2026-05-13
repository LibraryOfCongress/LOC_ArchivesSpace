{
  "items" => {
    "type" => "array",
    "items" => {
      "type" => "object",
      "properties" => {
        "event_date" => {"type" => nil},
        "date_from" => {"type" => "string", "maxLength" => 255},
        "date_to" => {"type" => "string", "maxLength" => 255},
        "date_singular" => {"type" => "string", "maxLength" => 255},
        "place" => {"type" => "string", "maxLength" => 255},
        "events" => {
          "type" => "array",
          "items" => {"type" => "string", "maxLength" => 65000}
        }
      }
    }
  }
}
