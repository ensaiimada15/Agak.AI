enum VoiceFormFieldType { text, number, phone, date }

class VoiceFormField {
  const VoiceFormField({
    required this.id,
    required this.label,
    required this.question,
    this.type = VoiceFormFieldType.text,
    this.hint,
  });

  final String id;
  final String label;
  final String question;
  final VoiceFormFieldType type;
  final String? hint;
}

class VoiceFormDefinition {
  const VoiceFormDefinition({
    required this.title,
    required this.subtitle,
    required this.fields,
  });

  final String title;
  final String subtitle;
  final List<VoiceFormField> fields;
}

/// Sample form so the voice-filling flow can be built and tested before a
/// real backend/schema exists.
const pensionApplicationForm = VoiceFormDefinition(
  title: 'Social Pension Application',
  subtitle: 'Aplikasyon sa Social Pension',
  fields: [
    VoiceFormField(
      id: 'fullName',
      label: 'Full Name',
      question: 'What is your full name?',
      hint: 'e.g. Maria Dela Cruz',
    ),
    VoiceFormField(
      id: 'age',
      label: 'Age',
      question: 'How old are you?',
      type: VoiceFormFieldType.number,
      hint: 'e.g. 68',
    ),
    VoiceFormField(
      id: 'address',
      label: 'Home Address',
      question: 'What is your complete home address?',
      hint: 'e.g. 123 Rovira Road, Dumaguete City',
    ),
    VoiceFormField(
      id: 'barangay',
      label: 'Barangay',
      question: 'What barangay do you live in?',
      hint: 'e.g. Barangay Junob',
    ),
    VoiceFormField(
      id: 'oscaId',
      label: 'OSCA ID Number',
      question: 'What is your OSCA ID number?',
      hint: 'e.g. OSCA-2024-00123',
    ),
    VoiceFormField(
      id: 'contactNumber',
      label: 'Contact Number',
      question: 'What is your contact number?',
      type: VoiceFormFieldType.phone,
      hint: 'e.g. 0917 123 4567',
    ),
  ],
);
