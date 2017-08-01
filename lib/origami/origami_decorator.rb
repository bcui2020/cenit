require 'openssl'
require 'origami'

Origami.module_eval do
  self::PDF.class_eval do
    def to_blob
      send :output
    end
  end

  def self.sign_pdf(input_pdf, options = {})
    records = Cenit.namespace(options[:namespace]).data_type(options[:data_type]).records_model.all.first

    passphrase = records[:PassPhrase]
    key4pem = records[:RSAPrivateKey]

    key = OpenSSL::PKey::RSA.new key4pem, passphrase
    cert = OpenSSL::X509::Certificate.new records[:X509Certificate]

    pdf = self::PDF.read(input_pdf.tempfile.path)
    filename_parts = input_pdf.original_filename.split('.')
    filename = filename_parts[0]+'_signed.'+filename_parts[1]
    input_pdf.tempfile.close!

    # Add signature annotation (so it becomes visibles in pdf document)
    page = pdf.get_page(1)
    sigannot = self::Annotation::Widget::Signature.new
    sigannot.Rect = self::Rectangle[:llx => 89.0, :lly => 386.0, :urx => 190.0, :ury => 353.0]
    page.add_annotation(sigannot)

    # Sign the PDF with the specified keys
    pdf.sign(cert, key,
             :method => 'adbe.pkcs7.sha1',
             :annotation => sigannot,
             :location => records[:Location],
             :contact => records[:Contact],
             :reason => records[:Reason]
    )
    return pdf.to_blob, filename
  end
end
