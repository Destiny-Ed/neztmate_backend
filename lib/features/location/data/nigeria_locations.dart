class NigeriaLocations {
  static const Map<String, List<String>> stateCities = {
    'Lagos': ['Ikeja', 'Lekki', 'Victoria Island', 'Yaba', 'Surulere', 'Ajah', 'Ikorodu', 'Badagry', 'Other'],
    'Abuja': ['Garki', 'Wuse', 'Maitama', 'Asokoro', 'Gwarinpa', 'Kubwa', 'Lugbe', 'Other'],
    'Rivers': ['Port Harcourt', 'Obio-Akpor', 'Eleme', 'Okrika', 'Other'],
    'Oyo': ['Ibadan', 'Ogbomoso', 'Oyo', 'Iseyin', 'Other'],
    'Ogun': ['Abeokuta', 'Ijebu-Ode', 'Sango-Ota', 'Sagamu', 'Other'],
    'Kano': ['Kano Municipal', 'Nassarawa', 'Fagge', 'Other'],
    'Kaduna': ['Kaduna North', 'Kaduna South', 'Zaria', 'Other'],
    'Enugu': ['Enugu', 'Nsukka', 'Other'],
    'Anambra': ['Awka', 'Onitsha', 'Nnewi', 'Other'],
    'Delta': ['Asaba', 'Warri', 'Sapele', 'Other'],
    'Edo': ['Benin City', 'Auchi', 'Other'],
    'Imo': ['Owerri', 'Orlu', 'Okigwe', 'Other'],
    'Akwa Ibom': ['Uyo', 'Eket', 'Other'],
    'Others': ['Other'],
  };

  static List<String> get states => stateCities.keys.toList()..sort();

  static List<String> citiesFor(String state) {
    return List<String>.from(stateCities[state] ?? ['Other']);
  }
}
