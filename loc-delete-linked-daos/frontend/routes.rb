ArchivesSpace::Application.routes.draw do
  scope AppConfig[:frontend_proxy_prefix] do
    post "/resources/:id/delete_with_digital_objects", to: "loc_resources_ext#delete_with_digital_objects"
  end
end
