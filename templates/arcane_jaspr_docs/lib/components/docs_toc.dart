import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

/// Table of contents sidebar for documentation pages
class DocsToc extends StatelessComponent {
  final List<TocEntry> tableOfContents;

  const DocsToc({
    super.key,
    required this.tableOfContents,
  });

  @override
  Component build(BuildContext context) {
    return Div(
      styles: ArcaneStyleData(
        width: '220px',
        flexShrink: '0',
        position: 'sticky',
        top: '80px',
        alignSelf: 'start',
        maxHeight: 'calc(100vh - 100px)',
        overflow: 'auto',
      ),
      children: [
        Div.child(
          styles: ArcaneStyleData(
            fontSize: FontSizePreset.sm,
            fontWeight: FontWeightPreset.semibold,
            color: ArcaneColors.textMuted,
            marginBottom: ArcaneSpacing.md,
            textTransform: 'uppercase',
            letterSpacing: '0.05em',
          ),
          child: Text('On this page'),
        ),
        Div(
          styles: ArcaneStyleData(
            display: Display.flex,
            flexDirection: FlexDirection.column,
            gap: Gap.xs,
            borderLeft: '1px solid ${ArcaneColors.border}',
            paddingLeft: ArcaneSpacing.md,
          ),
          children: tableOfContents.map(_buildTocItem).toList(),
        ),
      ],
    );
  }

  Component _buildTocItem(TocEntry entry) {
    final indent = (entry.level - 1) * 12;

    return a(
      href: '#${entry.id}',
      [
        Div.child(
          styles: ArcaneStyleData(
            fontSize: FontSizePreset.sm,
            color: ArcaneColors.textMuted,
            paddingLeft: '${indent}px',
            paddingTop: ArcaneSpacing.xs,
            paddingBottom: ArcaneSpacing.xs,
            transition: ArcaneEffects.transitionFast,
          ),
          child: Text(entry.text),
        ),
      ],
    );
  }
}
