import 'package:flutter/material.dart';
import 'package:flutter_application_chrono_metrics/commons/widgets/record_drawer.dart';

class PageLayoutBase extends StatefulWidget {
  final RecordDrawer recordDrawer;
  final Widget headerWidget;
  final Widget bodyWidget;
  final Widget footerWidget;

  const PageLayoutBase({
    super.key,
    required this.recordDrawer,
    required this.headerWidget,
    required this.bodyWidget,
    required this.footerWidget,
  });

  @override
  State<PageLayoutBase> createState() => _PageLayoutBaseState();
}

class _PageLayoutBaseState extends State<PageLayoutBase> {
  FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: widget.recordDrawer,
      endDrawerEnableOpenDragGesture: false, // 드래그로 드로어 열기 비활성화
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: EdgeInsets.only(
                  right: constraints.maxWidth * 0.05,
                  bottom: constraints.maxHeight * 0.1,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: constraints.maxHeight * 0.1, child: widget.headerWidget),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: constraints.maxWidth * 0.05,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: widget.bodyWidget,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: constraints.maxHeight * 0.05,
                      child: widget.footerWidget,
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            right: 0,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: Builder(
              builder: (BuildContext context) {
                return Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inversePrimary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_vert),
                    iconSize: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    constraints: const BoxConstraints(),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
