class AiTryOnDefaults {
  // Replace this with your public standard mannequin image URL.
  // Best practice: upload one shared mannequin image to Supabase Storage
  // and paste the public URL here.
  static const String standardMannequinImageUrl =
      'https://iwpczevhetourgorfdwc.supabase.co/storage/v1/object/public/clothes-images/shared/standard-mannequin.png';

  static const String defaultPrompt =
      'Dress the standard mannequin in the garment image realistically. Preserve the product design, do not alter the garment, keep the mannequin proportions stable, and match lighting, shadows, and fabric behavior naturally.';
}
