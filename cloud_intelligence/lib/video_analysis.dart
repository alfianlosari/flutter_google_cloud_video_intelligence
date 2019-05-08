class VideoAnalysis {
  final List<LabelAnnotation> annotations;

  VideoAnalysis({this.annotations});

  factory VideoAnalysis.fromJson(Map<String, dynamic> json) {
    List<LabelAnnotation> annotations = [];

    final result = json['annotation_results'][0];

    if (result['segment_label_annotations'] != null) {
      final segmentAnnotations = result['segment_label_annotations'] as List;

      annotations = segmentAnnotations
          .map((s) => LabelAnnotation(title: s['entity']['description']))
          .toList();
    }

    return VideoAnalysis(annotations: annotations);
  }
}

class LabelAnnotation {
  final String title;

  LabelAnnotation({this.title});
}
