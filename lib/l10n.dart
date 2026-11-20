import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple built-in translations: English (en), French (fr), Kinyarwanda (rw).
///
/// Use `t('key')` or `t('key', {'n': 3})` anywhere. Text in the database
/// (names, notes, measurement names such as "Neck") is stored as typed /
/// in English and only *displayed* translated, so backups work in any language.
class L10n extends ChangeNotifier {
  L10n._();
  static final L10n instance = L10n._();

  static const languages = {
    'en': 'English',
    'fr': 'Français',
    'rw': 'Kinyarwanda',
  };

  String lang = 'en';

  int get _i => lang == 'fr' ? 1 : (lang == 'rw' ? 2 : 0);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('lang');
    if (saved != null && languages.containsKey(saved)) {
      lang = saved;
      return;
    }
    // First launch: follow the phone's language when we support it.
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    lang = languages.containsKey(device) ? device : 'en';
  }

  Future<void> setLang(String v) async {
    if (!languages.containsKey(v) || v == lang) return;
    lang = v;
    (await SharedPreferences.getInstance()).setString('lang', v);
    notifyListeners();
  }

  /// Flutter's built-in widgets (date picker, etc.) have no Kinyarwanda, so
  /// they use English when Kinyarwanda is selected. Our own text is translated.
  Locale get materialLocale => Locale(lang == 'fr' ? 'fr' : 'en');
}

String t(String key, [Map<String, Object?>? args]) {
  final row = _strings[key];
  if (row == null) return key;
  var s = row[L10n.instance._i];
  if (s.isEmpty) s = row[0];
  if (args != null) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  }
  return s;
}

/// Display name of a body measurement (custom ones are shown as typed).
String measureLabel(String key) =>
    _strings.containsKey('m.$key') ? t('m.$key') : key;

// ------------------------------------------------------------------ dates

const _months = [
  ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'],
  ['Mut', 'Gas', 'Wer', 'Mat', 'Gic', 'Kam', 'Nya', 'Kan', 'Nze', 'Ukw', 'Ugu', 'Uku'],
];

// DateTime.weekday: Monday = 1 ... Sunday = 7
const _weekdays = [
  ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'],
  ['Mbe', 'Kab', 'Gtu', 'Kan', 'Gtn', 'Gnd', 'Cyu'],
];

String monthShort(int m) => _months[L10n.instance._i][m - 1];
String weekdayShort(int w) => _weekdays[L10n.instance._i][w - 1];

String fmtDate(DateTime d) =>
    '${weekdayShort(d.weekday)} ${d.day} ${monthShort(d.month)} ${d.year}';

String fmtShort(DateTime d) =>
    '${weekdayShort(d.weekday)} ${d.day} ${monthShort(d.month)}';

String fmtDateTime(DateTime d) =>
    '${d.day} ${monthShort(d.month)} ${d.year}, '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ------------------------------------------------------------ translations
// Order of each row: [English, French, Kinyarwanda]

const Map<String, List<String>> _strings = {
  // ---- general
  'save': ['Save', 'Enregistrer', 'Bika'],
  'cancel': ['Cancel', 'Annuler', 'Hagarika'],
  'delete': ['Delete', 'Supprimer', 'Siba'],
  'add': ['Add', 'Ajouter', 'Ongeraho'],
  'call': ['Call', 'Appeler', 'Hamagara'],
  'whatsapp': ['WhatsApp', 'WhatsApp', 'WhatsApp'],
  'required': ['Required', 'Obligatoire', 'Birakenewe'],
  'no.results': ['No results', 'Aucun résultat', 'Nta cyabonetse'],
  'photo.take': ['Take a photo', 'Prendre une photo', 'Fata ifoto'],
  'photo.gallery': ['Choose from gallery', 'Choisir dans la galerie', 'Hitamo muri galeri'],
  'photo.remove': ['Remove photo', 'Supprimer la photo', 'Siba ifoto'],

  // ---- navigation
  'nav.orders': ['Orders', 'Commandes', 'Komande'],
  'nav.clients': ['Clients', 'Clients', 'Abakiriya'],
  'nav.settings': ['Settings', 'Paramètres', 'Igenamiterere'],
  'fab.newOrder': ['New order', 'Nouvelle commande', 'Komande nshya'],
  'fab.newClient': ['New client', 'Nouveau client', 'Umukiriya mushya'],

  // ---- status
  'status.in_progress': ['In progress', 'En cours', 'Birimo gukorwa'],
  'status.ready': ['Ready for pickup', 'Prête à retirer', 'Byiteguye gufatwa'],
  'status.delivered': ['Delivered', 'Livrée', 'Byatanzwe'],

  // ---- orders tab
  'orders.search': [
    'Search name, phone, model, notes',
    'Rechercher nom, téléphone, modèle, notes',
    'Shakisha izina, telefone, modeli, inyandiko'
  ],
  'filter.todo': ['To do', 'À faire', 'Ibigomba gukorwa'],
  'filter.done': ['Delivered', 'Livrées', 'Byatanzwe'],
  'filter.all': ['All', 'Toutes', 'Byose'],
  'busy.banner': [
    'Busy days: {list}{more}',
    'Jours chargés : {list}{more}',
    'Iminsi y\'akazi kenshi: {list}{more}'
  ],
  'busy.item': [
    '{date} ({n} orders)',
    '{date} ({n} commandes)',
    '{date} (komande {n})'
  ],
  'busy.more': [' and {n} more', ' et {n} de plus', ' n\'izindi {n}'],
  'orders.empty': [
    'No orders here yet',
    'Aucune commande ici pour le moment',
    'Nta komande ziraboneka hano'
  ],
  'tile.overdue': ['Overdue {n}d', 'En retard de {n} j', 'Byarengeje iminsi {n}'],
  'tile.today': ['Due today', 'Pour aujourd\'hui', 'Uyu munsi'],
  'tile.tomorrow': ['Due tomorrow', 'Pour demain', 'Ejo'],
  'tile.inDays': ['In {n} days', 'Dans {n} jours', 'Mu minsi {n}'],
  'tile.busy': [' busy day', ' jour chargé', ' umunsi w\'akazi kenshi'],

  // ---- clients tab
  'clients.search': [
    'Search clients by name, phone or email',
    'Rechercher un client par nom, téléphone ou e-mail',
    'Shakisha umukiriya ukoresheje izina, telefone cyangwa imeri'
  ],
  'clients.empty': [
    'No clients yet',
    'Aucun client pour le moment',
    'Nta bakiriya barabaho'
  ],

  // ---- client form
  'cf.new': ['New client', 'Nouveau client', 'Umukiriya mushya'],
  'cf.edit': ['Edit client', 'Modifier le client', 'Hindura umukiriya'],
  'cf.photo': ['Client photo', 'Photo du client', 'Ifoto y\'umukiriya'],
  'cf.name': ['Full name *', 'Nom complet *', 'Amazina yombi *'],
  'cf.nameReq': ['Enter a name', 'Entrez un nom', 'Andika izina'],
  'cf.phone': ['Phone', 'Téléphone', 'Telefone'],
  'cf.email': ['Email', 'E-mail', 'Imeri'],
  'cf.notes': ['Notes about this client', 'Notes sur ce client', 'Ibyerekeye uyu mukiriya'],
  'cf.contactReq': [
    'Enter a phone number or an email',
    'Entrez un numéro de téléphone ou un e-mail',
    'Andika nimero ya telefone cyangwa imeri'
  ],
  'cf.badEmail': ['Not a valid email', 'E-mail invalide', 'Imeri si yo'],

  // ---- client detail
  'cd.delTitle': ['Delete {name}?', 'Supprimer {name} ?', 'Gusiba {name}?'],
  'cd.delBody': [
    'This also deletes {n} order(s) and all photos of this client. This cannot be undone.',
    'Cela supprime aussi {n} commande(s) et toutes les photos de ce client. Action irréversible.',
    'Ibi binasiba komande {n} n\'amafoto yose y\'uyu mukiriya. Ntibishobora gusubizwa inyuma.'
  ],
  'cd.orders': ['Orders ({n})', 'Commandes ({n})', 'Komande ({n})'],
  'cd.noOrders': [
    'No orders for this client yet.',
    'Aucune commande pour ce client.',
    'Nta komande uyu mukiriya aragira.'
  ],
  'cd.order': ['Order', 'Commande', 'Komande'],
  'cd.due': ['Due {date} · {status}', 'Pour le {date} · {status}', 'Itariki {date} · {status}'],

  // ---- order form
  'of.new': ['New order', 'Nouvelle commande', 'Komande nshya'],
  'of.edit': ['Edit order', 'Modifier la commande', 'Hindura komande'],
  'of.chooseClient': ['Choose a client', 'Choisir un client', 'Hitamo umukiriya'],
  'of.chooseFirst': [
    'Choose a client first',
    'Choisissez d\'abord un client',
    'Banza uhitemo umukiriya'
  ],
  'of.received': ['Order received', 'Commande reçue', 'Itariki komande yakiriwe'],
  'of.deadline': ['Deadline', 'Date limite', 'Itariki ntarengwa'],
  'of.busyWarn': [
    'Busy day: {n} other order(s) are already due then. Consider another date.',
    'Jour chargé : {n} autre(s) commande(s) sont déjà prévues ce jour-là. Pensez à une autre date.',
    'Umunsi w\'akazi kenshi: komande {n} zindi zigomba gutangwa uwo munsi. Tekereza indi tariki.'
  ],
  'of.sameDay': [
    '{n} other order(s) already due on this date.',
    '{n} autre(s) commande(s) déjà prévues à cette date.',
    'Komande {n} zindi zigomba gutangwa kuri iyi tariki.'
  ],
  'of.cloth': ['Cloth received', 'Tissu reçu', 'Igitambaro cyakiriwe'],
  'of.modelPhoto': ['Model to sew', 'Modèle à coudre', 'Modeli yo kudoda'],
  'of.model': [
    'Model / what to make',
    'Modèle / ce qu\'il faut confectionner',
    'Modeli / icyo kudoda'
  ],
  'of.modelHint': [
    'e.g. Kitenge dress, long sleeves, V neck',
    'ex. robe en kitenge, manches longues, col en V',
    'urugero: Ikanzu ya kitenge, amaboko maremare, ijosi rya V'
  ],
  'of.measure': ['Body measurements (cm)', 'Mensurations (cm)', 'Ibipimo by\'umubiri (cm)'],
  'of.copyLast': [
    'Copy from last order',
    'Copier de la dernière commande',
    'Kopera ku komande ya nyuma'
  ],
  'of.addMeasure': ['Add measurement', 'Ajouter une mesure', 'Ongeraho ikipimo'],
  'of.noEarlier': [
    'No earlier measurements for this client',
    'Aucune mesure précédente pour ce client',
    'Nta bipimo bya mbere uyu mukiriya afite'
  ],
  'of.copied': [
    'Copied from the last order - check them',
    'Copié de la dernière commande - vérifiez',
    'Byakopewe kuri komande ya nyuma - ubisuzume'
  ],
  'of.addTitle': ['Add a measurement', 'Ajouter une mesure', 'Ongeraho ikipimo'],
  'of.addName': [
    'Name (e.g. Cuff, Skirt length)',
    'Nom (ex. poignet, longueur de jupe)',
    'Izina (urugero: Uburebure bw\'ijipo)'
  ],
  'of.details': ['Additional details', 'Détails supplémentaires', 'Ibindi bisobanuro'],
  'of.detailsHint': [
    'Buttons, lining, embroidery, fitting date...',
    'Boutons, doublure, broderie, date d\'essayage...',
    'Utubuto, imbere y\'umwenda, ubudodo bw\'ubugeni, itariki yo kugerageza...'
  ],
  'of.price': ['Price (RWF)', 'Prix (RWF)', 'Igiciro (RWF)'],
  'of.deposit': ['Paid in advance', 'Acompte versé', 'Avansi yishyuwe'],
  'of.status': ['Status', 'Statut', 'Uko bihagaze'],
  'of.searchClients': ['Search clients', 'Rechercher des clients', 'Shakisha abakiriya'],

  // ---- order detail
  'od.title': ['Order', 'Commande', 'Komande'],
  'od.delTitle': ['Delete this order?', 'Supprimer cette commande ?', 'Gusiba iyi komande?'],
  'od.delBody': [
    'The order and its photos will be removed.',
    'La commande et ses photos seront supprimées.',
    'Komande n\'amafoto yayo bizasibwa.'
  ],
  'od.received': ['Received', 'Reçue', 'Yakiriwe'],
  'od.overdueBy': [
    'Overdue by {n} day(s)',
    'En retard de {n} jour(s)',
    'Yarengeje iminsi {n}'
  ],
  'od.dueToday': ['Due today', 'Pour aujourd\'hui', 'Uyu munsi'],
  'od.inDays': ['In {n} day(s)', 'Dans {n} jour(s)', 'Mu minsi {n}'],
  'od.model': ['Model', 'Modèle', 'Modeli'],
  'od.measure': ['Measurements (cm)', 'Mensurations (cm)', 'Ibipimo (cm)'],
  'od.none': ['None recorded', 'Aucune enregistrée', 'Nta bipimo byanditswe'],
  'od.price': ['Price', 'Prix', 'Igiciro'],
  'od.balance': ['Balance to pay', 'Reste à payer', 'Asigaye kwishyurwa'],

  // ---- settings
  'st.language': ['Language', 'Langue', 'Ururimi'],
  'st.backup': ['Backup', 'Sauvegarde', 'Backup (kubika amakuru)'],
  'st.backupInfo': [
    'Everything is saved on this phone first, so the app works without internet. When you are online and signed in, it is backed up to your own Google account automatically. If you change or lose your phone, sign in with the same account and restore.',
    'Tout est d\'abord enregistré sur ce téléphone, l\'application fonctionne donc sans internet. Quand vous êtes en ligne et connecté, une sauvegarde est faite automatiquement sur votre propre compte Google. Si vous changez ou perdez de téléphone, connectez-vous avec le même compte et restaurez.',
    'Ibintu byose bibikwa mbere kuri telefone, bityo porogaramu ikora nta interineti. Iyo ufite interineti kandi winjiye muri konti yawe ya Google, amakuru abikwa kuri konti yawe mu buryo bwikora. Niba uhinduye telefone cyangwa warayitakaje, injira muri konti imwe ya Google maze ukande Garura.'
  ],
  'st.notSigned': [
    'Not signed in - no online backup yet.',
    'Non connecté - pas encore de sauvegarde en ligne.',
    'Ntabwo winjiye - nta backup kuri interineti iraba.'
  ],
  'st.signIn': ['Sign in with Google', 'Se connecter avec Google', 'Injira ukoresheje Google'],
  'st.noBackup': ['No backup yet', 'Aucune sauvegarde', 'Nta backup iraba'],
  'st.lastBackup': [
    'Last backup: {when}',
    'Dernière sauvegarde : {when}',
    'Backup ya nyuma: {when}'
  ],
  'st.failed': [
    'Last attempt failed - will retry when online.',
    'Dernière tentative échouée - nouvel essai dès que la connexion revient.',
    'Igerageza rya nyuma ryanze - hazongera kugeragezwa ubonye interineti.'
  ],
  'st.backupNow': ['Back up now', 'Sauvegarder maintenant', 'Bika amakuru nonaha'],
  'st.restore': ['Restore', 'Restaurer', 'Garura amakuru'],
  'st.signOut': ['Sign out', 'Se déconnecter', 'Sohoka'],
  'st.restoreTitle': [
    'Restore from backup?',
    'Restaurer la sauvegarde ?',
    'Garura amakuru muri backup?'
  ],
  'st.restoreBody': [
    'All clients and orders currently on this phone will be REPLACED by the latest backup from your Google account.',
    'Tous les clients et commandes présents sur ce téléphone seront REMPLACÉS par la dernière sauvegarde de votre compte Google.',
    'Abakiriya na komande byose biri kuri iyi telefone BIZASIGANWA na backup ya nyuma iri kuri konti yawe ya Google.'
  ],
  'st.errSignIn': [
    'Could not sign in. Check your internet and try again.',
    'Connexion impossible. Vérifiez votre internet et réessayez.',
    'Kwinjira ntibyashobotse. Genzura interineti wongere ugerageze.'
  ],
  'st.errBackup': [
    'Could not back up. Check your internet and try again.',
    'Sauvegarde impossible. Vérifiez votre internet et réessayez.',
    'Kubika ntibyashobotse. Genzura interineti wongere ugerageze.'
  ],
  'st.errRestore': [
    'Could not restore. Check your internet and try again.',
    'Restauration impossible. Vérifiez votre internet et réessayez.',
    'Kugarura ntibyashobotse. Genzura interineti wongere ugerageze.'
  ],
  'st.backupSaved': [
    'Backup saved to your Google account',
    'Sauvegarde enregistrée sur votre compte Google',
    'Backup yabitswe kuri konti yawe ya Google'
  ],
  'st.restoreDone': ['Restore complete', 'Restauration terminée', 'Kugarura byarangiye'],
  'st.noBackupFound': [
    'No backup found in this Google account',
    'Aucune sauvegarde trouvée dans ce compte Google',
    'Nta backup yabonetse kuri iyi konti ya Google'
  ],
  'st.reminders': ['Reminders', 'Rappels', 'Kwibutsa'],
  'st.busyDef': [
    'Busy day = {n} or more orders due on the same date',
    'Jour chargé = {n} commandes ou plus à la même date',
    'Umunsi w\'akazi kenshi = komande {n} cyangwa zirenga ku itariki imwe'
  ],
  'st.remindAt': ['Remind me at {h}:00', 'Me rappeler à {h}h00', 'Unyibutse saa {h}:00'],
  'st.remindInfo': [
    'Normal days: reminders 2 days before, 1 day before and on the day. Busy days: extra early warnings 5 and 3 days before. You also get a reminder the day after a missed deadline.',
    'Jours normaux : rappels 2 jours avant, 1 jour avant et le jour même. Jours chargés : alertes supplémentaires 5 et 3 jours avant. Vous recevez aussi un rappel le lendemain d\'une date limite dépassée.',
    'Iminsi isanzwe: kwibutsa hasigaye iminsi 2, umunsi 1 no ku munsi nyirizina. Iminsi y\'akazi kenshi: kwibutsa hakiri kare hasigaye iminsi 5 na 3. Unibutswa ejo hakurikira itariki ntarengwa yarengeje.'
  ],
  'st.allowTest': [
    'Allow & test notifications',
    'Autoriser et tester les notifications',
    'Emera kandi ugerageze imenyesha'
  ],
  'st.blocked': [
    'Notifications are blocked. Enable them in phone settings.',
    'Les notifications sont bloquées. Activez-les dans les paramètres du téléphone.',
    'Imenyesha ryarafunzwe. Ribyemeze mu igenamiterere rya telefone.'
  ],

  // ---- reminder notifications
  'n.one': ['1 order', '1 commande', 'komande 1'],
  'n.many': ['{n} orders', '{n} commandes', 'komande {n}'],
  'n.when.days': ['in {d} days', 'dans {d} jours', 'mu minsi {d}'],
  'n.when.tomorrow': ['tomorrow', 'demain', 'ejo'],
  'n.when.today': ['today', 'aujourd\'hui', 'uyu munsi'],
  'n.title': ['{orders} due {when}', 'À rendre {when} : {orders}', 'Gutanga {when}: {orders}'],
  'n.busy': [
    'Busy day: {orders} due {when}',
    'Jour chargé : {orders} à rendre {when}',
    'Akazi kenshi: gutanga {when}: {orders}'
  ],
  'n.overdue': [
    'Overdue: {orders} due yesterday',
    'En retard : {orders} à rendre hier',
    'Byarengeje: {orders} byagombaga gutangwa ejo hashize'
  ],
  'n.more': ['{names} and {n} more', '{names} et {n} autres', '{names} n\'abandi {n}'],
  'n.testTitle': [
    'Reminders are working',
    'Les rappels fonctionnent',
    'Kwibutsa bikora neza'
  ],
  'n.testBody': [
    'You will be reminded before each order deadline.',
    'Vous serez averti avant chaque date limite.',
    'Uzibutswa mbere y\'itariki ntarengwa ya buri komande.'
  ],

  // ---- body measurements (keys are the English names stored in the database)
  'm.Neck': ['Neck', 'Cou', 'Ijosi'],
  'm.Shoulder': ['Shoulder', 'Épaules', 'Urutugu'],
  'm.Chest': ['Chest', 'Poitrine', 'Igituza'],
  'm.Waist': ['Waist', 'Taille', 'Mu rukenyerero'],
  'm.Hip': ['Hip', 'Hanches', 'Ikibuno'],
  'm.Back length': ['Back length', 'Longueur dos', 'Uburebure bw\'umugongo'],
  'm.Sleeve length': ['Sleeve length', 'Longueur manche', 'Uburebure bw\'umukono'],
  'm.Bicep': ['Bicep', 'Biceps', 'Akaboko'],
  'm.Wrist': ['Wrist', 'Poignet', 'Ukuboko (ku kiganza)'],
  'm.Top length': ['Top length', 'Longueur haut', 'Uburebure bw\'ishati'],
  'm.Thigh': ['Thigh', 'Cuisse', 'Itako'],
  'm.Knee': ['Knee', 'Genou', 'Ivi'],
  'm.Ankle': ['Ankle', 'Cheville', 'Mu kaguru'],
  'm.Inseam': ['Inseam', 'Entrejambe', 'Uburebure bw\'imbere bw\'ipantaro'],
  'm.Outseam': ['Outseam', 'Longueur extérieure', 'Uburebure bw\'ipantaro'],
  'm.Height': ['Height', 'Hauteur (stature)', 'Uburebure'],
};
