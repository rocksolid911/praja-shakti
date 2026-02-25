import '../../../core/models/project.dart';

abstract class ProjectState {}

class ProjectInitial extends ProjectState {}

class ProjectLoading extends ProjectState {}

class ProjectsLoaded extends ProjectState {
  final List<Project> projects;
  final String? activeFilter;

  ProjectsLoaded({required this.projects, this.activeFilter});
}

class ProjectDetailLoaded extends ProjectState {
  final Project project;
  ProjectDetailLoaded(this.project);
}

class ProjectError extends ProjectState {
  final String message;
  ProjectError(this.message);
}

class ProjectAdopted extends ProjectState {
  final Project project;
  ProjectAdopted(this.project);
}
