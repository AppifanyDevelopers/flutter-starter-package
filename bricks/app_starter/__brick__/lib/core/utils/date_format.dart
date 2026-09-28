const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A minimal "MMM d, yyyy" formatter (e.g. "Jan 5, 1990") -- avoids pulling
/// in `intl` for a single date field.
String formatDate(DateTime date) => '${_months[date.month - 1]} ${date.day}, ${date.year}';
