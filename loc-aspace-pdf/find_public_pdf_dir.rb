class LocPDFDirectoryFinder

  def self.loc_pdf_published_dir
    # Look for a deployment-defined directory for the auto-generated pdfs.
    # if one doesn't exist, create one here.
    pdf_dir = if AppConfig.has_key?(:loc_pdf_published_dir) && Dir.exists?(AppConfig[:loc_pdf_published_dir])
                AppConfig[:loc_pdf_published_dir]
              else
                pdf_dir = File.join(AppConfig[:data_directory], "shared", 'public_pdfs')
                FileUtils.mkdir_p(pdf_dir)
                File.expand_path(pdf_dir)
              end
    pdf_dir
  end
end
