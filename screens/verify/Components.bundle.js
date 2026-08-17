// Components bundle — 3 component(s) materialized from a .fig as one
// self-contained file: no imports/exports; every component is assigned to window below.
// Design tokens / typography still ship separately (fig-tokens.css / fig-typography.css).

// figma node: 2:19 Screen Corners / Top Corners
function PhotoVerifyCorners(_p = {}) {
  const props = _p;
  return /*#__PURE__*/React.createElement("div", {
    className: props.className,
    style: {
      width: 375,
      height: 18,
      position: "relative",
      ...props.style
    }
  });
}

// figma node: 63:812 Start screen
function PhotoVerify1(_p = {}) {
  const props = _p;
  return /*#__PURE__*/React.createElement("div", {
    className: props.className,
    style: {
      width: 375,
      height: 812,
      overflow: "hidden",
      borderRadius: 8,
      backgroundColor: "rgb(255,255,255)",
      position: "relative",
      color: "rgb(0,0,0)",
      ...props.style
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "fig-asset-aab1efb98f0c6da0-15309607",
    style: {
      position: "absolute",
      left: -78,
      top: 431,
      width: 867,
      height: 437
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 788,
      width: 375,
      height: 24,
      display: "flex",
      flexDirection: "column",
      gap: 10,
      padding: "10px 10px 10px 10px",
      justifyContent: "center",
      alignItems: "center",
      flexWrap: "nowrap",
      boxSizing: "border-box"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: 131,
      height: 5,
      opacity: 0.9,
      borderRadius: 100,
      backgroundColor: "rgb(0,0,0)",
      flexShrink: 0
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      width: 375,
      height: 48
    }
  }, /*#__PURE__*/React.createElement(PhotoVerifyCorners, {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      width: 375,
      height: 18
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 287,
      top: 0,
      width: 88,
      height: 48
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: 15,
    height: 11,
    viewBox: "0 0 15 11",
    fill: "none",
    style: {
      position: "absolute",
      left: 26,
      top: 18,
      width: 15,
      height: 11
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 5.112 8.72 C 6.491 7.761 8.51 7.761 9.889 8.72 C 9.958 8.771 9.998 8.844 10 8.921 C 10.002 8.998 9.965 9.072 9.898 9.126 L 7.739 10.918 C 7.676 10.97 7.59 11 7.5 11 C 7.41 11 7.324 10.97 7.261 10.918 L 5.102 9.126 C 5.035 9.072 4.998 8.998 5 8.921 C 5.002 8.844 5.043 8.771 5.112 8.72 Z M 3.099 6.11 C 5.861 3.297 10.139 3.297 12.901 6.11 C 12.964 6.176 12.999 6.267 13 6.362 C 13.001 6.457 12.967 6.548 12.906 6.615 L 11.745 7.899 C 11.626 8.031 11.432 8.034 11.31 7.906 C 10.403 7.007 9.223 6.509 7.999 6.509 C 6.776 6.509 5.597 7.007 4.69 7.906 C 4.568 8.034 4.374 8.031 4.255 7.899 L 3.095 6.615 C 3.034 6.548 2.999 6.457 3 6.362 C 3.001 6.267 3.036 6.176 3.099 6.11 Z M 0.095 3.193 C 4.235 -1.064 10.765 -1.064 14.905 3.193 C 14.965 3.257 15 3.343 15 3.434 C 15 3.524 14.967 3.611 14.908 3.675 L 13.772 4.904 C 13.655 5.03 13.466 5.031 13.348 4.907 C 11.77 3.298 9.676 2.401 7.5 2.4 C 5.324 2.401 3.231 3.298 1.653 4.907 C 1.535 5.032 1.344 5.031 1.228 4.904 L 0.092 3.675 C 0.033 3.611 0 3.524 0 3.434 C 0.001 3.343 0.035 3.257 0.095 3.193 Z",
    fill: "currentColor",
    fillRule: "nonzero"
  })), /*#__PURE__*/React.createElement("svg", {
    width: 16,
    height: 11,
    viewBox: "0 0 16 11",
    fill: "none",
    style: {
      position: "absolute",
      left: 4,
      top: 18,
      width: 16,
      height: 11
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 2 7 C 2.552 7 3 7.448 3 8 L 3 10 C 3 10.552 2.552 11 2 11 L 1 11 C 0.448 11 0 10.552 0 10 L 0 8 C 0 7.448 0.448 7 1 7 L 2 7 Z M 6 5 C 6.552 5 7 5.448 7 6 L 7 10 C 7 10.552 6.552 11 6 11 L 5 11 C 4.448 11 4 10.552 4 10 L 4 6 C 4 5.448 4.448 5 5 5 L 6 5 Z M 11 2 C 11.552 2 12 2.484 12 3.08 L 12 9.92 C 12 10.516 11.552 11 11 11 L 10 11 C 9.448 11 9 10.516 9 9.92 L 9 3.08 C 9 2.484 9.448 2 10 2 L 11 2 Z M 15 0 C 15.552 0 16 0.462 16 1.031 L 16 9.969 C 16 10.538 15.552 11 15 11 L 14 11 C 13.448 11 13 10.538 13 9.969 L 13 1.031 C 13 0.462 13.448 0 14 0 L 15 0 Z",
    fill: "currentColor",
    fillRule: "nonzero"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 47,
      top: 18,
      width: 24,
      height: 11,
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      width: 22,
      height: 11,
      opacity: 0.35,
      borderRadius: 3,
      boxShadow: "inset 0 0 0 1px rgb(0,0,0)"
    }
  }), /*#__PURE__*/React.createElement("svg", {
    width: 1,
    height: 4,
    viewBox: "0 0 1 4",
    fill: "none",
    style: {
      position: "absolute",
      left: 23,
      top: 4,
      width: 1,
      height: 4,
      opacity: 0.4
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 0 0 L 0 4 C 0.606 3.661 1 2.873 1 2 C 1 1.127 0.606 0.339 0 0",
    fill: "currentColor",
    fillRule: "nonzero"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 2,
      top: 2,
      width: 18,
      height: 7,
      borderRadius: 1.5,
      backgroundColor: "rgb(0,0,0)"
    }
  }))), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      left: 23,
      top: 15,
      width: 54,
      height: 18,
      fontFamily: "\"SF Pro Text\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 15,
      textAlign: "center",
      lineHeight: "100%",
      letterSpacing: "-0.300px",
      color: "rgb(0,0,0)"
    }
  }, "12:48")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 24,
      top: 48,
      width: 327,
      height: 8,
      overflow: "hidden",
      borderRadius: 4,
      backgroundColor: "rgb(232,233,241)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: -1,
      top: 0,
      width: 57,
      height: 8,
      borderRadius: 8,
      backgroundColor: "rgb(234,129,46)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 25,
      top: 87,
      width: 335,
      display: "flex",
      flexDirection: "column",
      gap: 11,
      alignItems: "flex-start",
      flexWrap: "nowrap"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      display: "flex",
      flexDirection: "column",
      gap: 6,
      alignItems: "flex-start",
      flexWrap: "nowrap",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 21,
      lineHeight: "100%",
      color: "rgb(0,0,0)",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, "\u0414\u043E\u0431\u0440\u043E \u043F\u043E\u0436\u0430\u043B\u043E\u0432\u0430\u0442\u044C!"), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 500,
      fontSize: 15,
      lineHeight: "20px",
      color: "rgb(125,125,125)",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, "\u0421\u0430\u0442\u0443\u0301\u0440\u043D \u2014 \u0448\u0435\u0441\u0442\u0430\u044F \u043F\u043B\u0430\u043D\u0435\u0442\u0430 \u043F\u043E \u0443\u0434\u0430\u043B\u0451\u043D\u043D\u043E\u0441\u0442\u0438 \u043E\u0442 \u0421\u043E\u043B\u043D\u0446\u0430 \u0438 \u0432\u0442\u043E\u0440\u0430\u044F \u043F\u043E \u0440\u0430\u0437\u043C\u0435\u0440\u0430\u043C \u043F\u043B\u0430\u043D\u0435\u0442\u0430 \u0432 \u0421\u043E\u043B\u043D\u0435\u0447\u043D\u043E\u0439 \u0441\u0438\u0441\u0442\u0435\u043C\u0435 \u043F\u043E\u0441\u043B\u0435 \u042E\u043F\u0438\u0442\u0435\u0440\u0430.")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: 324,
      display: "flex",
      flexDirection: "column",
      gap: 12,
      alignItems: "flex-start",
      flexWrap: "nowrap",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      height: 36,
      borderRadius: 10,
      backgroundColor: "rgba(120,120,128,0.12)",
      display: "flex",
      flexDirection: "row",
      padding: "7px 8px 7px 8px",
      alignItems: "center",
      flexWrap: "nowrap",
      boxSizing: "border-box",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      width: 25,
      fontFamily: "\"SF Pro\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 400,
      fontSize: 17,
      lineHeight: "22px",
      color: "rgba(60,60,67,0.6)",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("svg", { width: 16, height: 16, viewBox: "0 0 16 16", fill: "none", style: { display: "block", marginTop: 3 } }, /*#__PURE__*/React.createElement("circle", { cx: 6.6, cy: 6.6, r: 5.1, stroke: "currentColor", strokeWidth: 1.7 }), /*#__PURE__*/React.createElement("path", { d: "M 10.4 10.4 L 14.4 14.4", stroke: "currentColor", strokeWidth: 1.7, strokeLinecap: "round" }))), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 400,
      fontSize: 15,
      whiteSpace: "nowrap",
      lineHeight: "22px",
      letterSpacing: "-0.430px",
      color: "rgba(60,60,67,0.6)",
      flexGrow: 1,
      alignSelf: "stretch"
    }
  }, "\u041D\u043E\u043C\u0435\u0440 \u0442\u0435\u043B\u0435\u0444\u043E\u043D\u0430 (\u0441 WhatsApp)")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      height: 36,
      borderRadius: 10,
      backgroundColor: "rgba(120,120,128,0.12)",
      display: "flex",
      flexDirection: "row",
      padding: "7px 8px 7px 8px",
      alignItems: "center",
      flexWrap: "nowrap",
      boxSizing: "border-box",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      width: 25,
      fontFamily: "\"SF Pro\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 400,
      fontSize: 17,
      lineHeight: "22px",
      color: "rgba(60,60,67,0.6)",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("svg", { width: 16, height: 16, viewBox: "0 0 16 16", fill: "none", style: { display: "block", marginTop: 3 } }, /*#__PURE__*/React.createElement("circle", { cx: 6.6, cy: 6.6, r: 5.1, stroke: "currentColor", strokeWidth: 1.7 }), /*#__PURE__*/React.createElement("path", { d: "M 10.4 10.4 L 14.4 14.4", stroke: "currentColor", strokeWidth: 1.7, strokeLinecap: "round" }))), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 400,
      fontSize: 15,
      whiteSpace: "nowrap",
      lineHeight: "22px",
      letterSpacing: "-0.430px",
      color: "rgba(60,60,67,0.6)",
      flexGrow: 1,
      alignSelf: "stretch"
    }
  }, "\u0418\u043C\u044F")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      height: 36,
      borderRadius: 10,
      backgroundColor: "rgba(120,120,128,0.12)",
      display: "flex",
      flexDirection: "row",
      padding: "7px 8px 7px 8px",
      alignItems: "center",
      flexWrap: "nowrap",
      boxSizing: "border-box",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      width: 25,
      fontFamily: "\"SF Pro\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 400,
      fontSize: 17,
      lineHeight: "22px",
      color: "rgba(60,60,67,0.6)",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("svg", { width: 16, height: 16, viewBox: "0 0 16 16", fill: "none", style: { display: "block", marginTop: 3 } }, /*#__PURE__*/React.createElement("circle", { cx: 6.6, cy: 6.6, r: 5.1, stroke: "currentColor", strokeWidth: 1.7 }), /*#__PURE__*/React.createElement("path", { d: "M 10.4 10.4 L 14.4 14.4", stroke: "currentColor", strokeWidth: 1.7, strokeLinecap: "round" }))), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 400,
      fontSize: 15,
      whiteSpace: "nowrap",
      lineHeight: "22px",
      letterSpacing: "-0.430px",
      color: "rgba(60,60,67,0.6)",
      flexGrow: 1,
      alignSelf: "stretch"
    }
  }, "\u041F\u0430\u0440\u043E\u043B\u044C")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      height: 36,
      borderRadius: 10,
      backgroundColor: "rgba(120,120,128,0.12)",
      display: "flex",
      flexDirection: "row",
      padding: "7px 8px 7px 8px",
      alignItems: "center",
      flexWrap: "nowrap",
      boxSizing: "border-box",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      width: 25,
      fontFamily: "\"SF Pro\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 400,
      fontSize: 17,
      lineHeight: "22px",
      color: "rgba(60,60,67,0.6)",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("svg", { width: 16, height: 16, viewBox: "0 0 16 16", fill: "none", style: { display: "block", marginTop: 3 } }, /*#__PURE__*/React.createElement("circle", { cx: 6.6, cy: 6.6, r: 5.1, stroke: "currentColor", strokeWidth: 1.7 }), /*#__PURE__*/React.createElement("path", { d: "M 10.4 10.4 L 14.4 14.4", stroke: "currentColor", strokeWidth: 1.7, strokeLinecap: "round" }))), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 400,
      fontSize: 15,
      whiteSpace: "nowrap",
      lineHeight: "22px",
      letterSpacing: "-0.430px",
      color: "rgba(60,60,67,0.6)",
      flexGrow: 1,
      alignSelf: "stretch"
    }
  }, "\u0418\u0418\u041D")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      height: 36,
      borderRadius: 10,
      backgroundColor: "rgb(234,129,46)",
      display: "flex",
      flexDirection: "row",
      gap: 10,
      padding: "15px 15px 15px 15px",
      justifyContent: "center",
      alignItems: "center",
      flexWrap: "nowrap",
      boxSizing: "border-box",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 17,
      whiteSpace: "nowrap",
      lineHeight: "22px",
      color: "rgb(255,255,255)",
      flexShrink: 0
    }
  }, "\u0414\u0430\u043B\u0435\u0435")))));
}

// figma node: 63:855 Start screen
function PhotoVerify2(_p = {}) {
  const props = _p;
  return /*#__PURE__*/React.createElement("div", {
    className: props.className,
    style: {
      width: 375,
      height: 812,
      overflow: "hidden",
      borderRadius: 8,
      backgroundColor: "rgb(255,255,255)",
      position: "relative",
      ...props.style
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "fig-asset-0d0941963f5141a8-a44c39b3",
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      transform: "matrix(0.866,0.500,-0.500,0.866,79,412)",
      transformOrigin: "0 0",
      width: 522.965,
      height: 460.87
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 788,
      width: 375,
      height: 24,
      display: "flex",
      flexDirection: "column",
      gap: 10,
      padding: "10px 10px 10px 10px",
      justifyContent: "center",
      alignItems: "center",
      flexWrap: "nowrap",
      boxSizing: "border-box"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: 131,
      height: 5,
      opacity: 0.9,
      borderRadius: 100,
      backgroundColor: "rgb(0,0,0)",
      flexShrink: 0
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      width: 375,
      height: 48
    }
  }, /*#__PURE__*/React.createElement(PhotoVerifyCorners, {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      width: 375,
      height: 18
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 287,
      top: 0,
      width: 88,
      height: 48
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: 15,
    height: 11,
    viewBox: "0 0 15 11",
    fill: "none",
    style: {
      position: "absolute",
      left: 26,
      top: 18,
      width: 15,
      height: 11,
      color: "rgb(0,0,0)"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 5.112 8.72 C 6.491 7.761 8.51 7.761 9.889 8.72 C 9.958 8.771 9.998 8.844 10 8.921 C 10.002 8.998 9.965 9.072 9.898 9.126 L 7.739 10.918 C 7.676 10.97 7.59 11 7.5 11 C 7.41 11 7.324 10.97 7.261 10.918 L 5.102 9.126 C 5.035 9.072 4.998 8.998 5 8.921 C 5.002 8.844 5.043 8.771 5.112 8.72 Z M 3.099 6.11 C 5.861 3.297 10.139 3.297 12.901 6.11 C 12.964 6.176 12.999 6.267 13 6.362 C 13.001 6.457 12.967 6.548 12.906 6.615 L 11.745 7.899 C 11.626 8.031 11.432 8.034 11.31 7.906 C 10.403 7.007 9.223 6.509 7.999 6.509 C 6.776 6.509 5.597 7.007 4.69 7.906 C 4.568 8.034 4.374 8.031 4.255 7.899 L 3.095 6.615 C 3.034 6.548 2.999 6.457 3 6.362 C 3.001 6.267 3.036 6.176 3.099 6.11 Z M 0.095 3.193 C 4.235 -1.064 10.765 -1.064 14.905 3.193 C 14.965 3.257 15 3.343 15 3.434 C 15 3.524 14.967 3.611 14.908 3.675 L 13.772 4.904 C 13.655 5.03 13.466 5.031 13.348 4.907 C 11.77 3.298 9.676 2.401 7.5 2.4 C 5.324 2.401 3.231 3.298 1.653 4.907 C 1.535 5.032 1.344 5.031 1.228 4.904 L 0.092 3.675 C 0.033 3.611 0 3.524 0 3.434 C 0.001 3.343 0.035 3.257 0.095 3.193 Z",
    fill: "currentColor",
    fillRule: "nonzero"
  })), /*#__PURE__*/React.createElement("svg", {
    width: 16,
    height: 11,
    viewBox: "0 0 16 11",
    fill: "none",
    style: {
      position: "absolute",
      left: 4,
      top: 18,
      width: 16,
      height: 11,
      color: "rgb(0,0,0)"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 2 7 C 2.552 7 3 7.448 3 8 L 3 10 C 3 10.552 2.552 11 2 11 L 1 11 C 0.448 11 0 10.552 0 10 L 0 8 C 0 7.448 0.448 7 1 7 L 2 7 Z M 6 5 C 6.552 5 7 5.448 7 6 L 7 10 C 7 10.552 6.552 11 6 11 L 5 11 C 4.448 11 4 10.552 4 10 L 4 6 C 4 5.448 4.448 5 5 5 L 6 5 Z M 11 2 C 11.552 2 12 2.484 12 3.08 L 12 9.92 C 12 10.516 11.552 11 11 11 L 10 11 C 9.448 11 9 10.516 9 9.92 L 9 3.08 C 9 2.484 9.448 2 10 2 L 11 2 Z M 15 0 C 15.552 0 16 0.462 16 1.031 L 16 9.969 C 16 10.538 15.552 11 15 11 L 14 11 C 13.448 11 13 10.538 13 9.969 L 13 1.031 C 13 0.462 13.448 0 14 0 L 15 0 Z",
    fill: "currentColor",
    fillRule: "nonzero"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 47,
      top: 18,
      width: 24,
      height: 11,
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      width: 22,
      height: 11,
      opacity: 0.35,
      borderRadius: 3,
      boxShadow: "inset 0 0 0 1px rgb(0,0,0)"
    }
  }), /*#__PURE__*/React.createElement("svg", {
    width: 1,
    height: 4,
    viewBox: "0 0 1 4",
    fill: "none",
    style: {
      position: "absolute",
      left: 23,
      top: 4,
      width: 1,
      height: 4,
      opacity: 0.4,
      color: "rgb(0,0,0)"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 0 0 L 0 4 C 0.606 3.661 1 2.873 1 2 C 1 1.127 0.606 0.339 0 0",
    fill: "currentColor",
    fillRule: "nonzero"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 2,
      top: 2,
      width: 18,
      height: 7,
      borderRadius: 1.5,
      backgroundColor: "rgb(0,0,0)"
    }
  }))), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      left: 23,
      top: 15,
      width: 54,
      height: 18,
      fontFamily: "\"SF Pro Text\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 15,
      textAlign: "center",
      lineHeight: "100%",
      letterSpacing: "-0.300px",
      color: "rgb(0,0,0)"
    }
  }, "12:48")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 24,
      top: 48,
      width: 327,
      height: 8,
      overflow: "hidden",
      borderRadius: 4,
      backgroundColor: "rgb(232,233,241)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: -1,
      top: 0,
      width: 143,
      height: 8,
      borderRadius: 8,
      backgroundColor: "rgb(234,129,46)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 23,
      top: 87,
      width: 273,
      display: "flex",
      flexDirection: "column",
      gap: 13,
      alignItems: "flex-start",
      flexWrap: "nowrap"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: 216,
      display: "flex",
      flexDirection: "column",
      gap: 6,
      alignItems: "flex-start",
      flexWrap: "nowrap",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 21,
      lineHeight: "28px",
      letterSpacing: "-0.010em",
      color: "rgb(0,0,0)",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, "\u041A\u043E\u0434 \u043F\u043E\u0434\u0442\u0432\u0435\u0440\u0436\u0434\u0435\u043D\u0438\u044F"), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      opacity: 0.8,
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 500,
      fontSize: 17,
      lineHeight: "22px",
      color: "rgb(125,125,125)",
      flexShrink: 0,
      alignSelf: "stretch",
      whiteSpace: "pre-wrap"
    }
  }, "Напишите 4х значный код,", "\n", "который был отправлен", "\n", "на номер ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: "rgb(234,129,46)"
    }
  }, "+996 997 919 170"))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      display: "flex",
      flexDirection: "row",
      gap: 16,
      alignItems: "center",
      flexWrap: "nowrap",
      flexShrink: 0,
      alignSelf: "stretch"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      display: "flex",
      flexDirection: "column",
      gap: 12,
      alignItems: "center",
      flexWrap: "nowrap",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 24,
      whiteSpace: "nowrap",
      lineHeight: "28px",
      letterSpacing: "-0.020em",
      color: "rgb(7,30,104)",
      flexShrink: 0
    }
  }, "7"), /*#__PURE__*/React.createElement("svg", {
    width: 56,
    height: 1,
    viewBox: "0 0 56 1",
    fill: "none",
    style: {
      position: "relative",
      width: 56,
      height: 1,
      flexShrink: 0,
      color: "rgb(7,30,104)"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 0.384 -0.5 L -0.616 -0.5 L -0.616 1.5 L 0.384 1.5 L 0.384 0.5 L 0.384 -0.5 Z M 55.616 1.5 L 56.616 1.5 L 56.616 -0.5 L 55.616 -0.5 L 55.616 0.5 L 55.616 1.5 Z M 0.384 0.5 L 0.384 1.5 L 55.616 1.5 L 55.616 0.5 L 55.616 -0.5 L 0.384 -0.5 L 0.384 0.5 Z",
    fill: "currentColor",
    fillRule: "nonzero"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      display: "flex",
      flexDirection: "column",
      gap: 12,
      alignItems: "center",
      flexWrap: "nowrap",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 24,
      whiteSpace: "nowrap",
      lineHeight: "28px",
      letterSpacing: "-0.020em",
      color: "rgb(28,25,57)",
      flexShrink: 0
    }
  }, "X"), /*#__PURE__*/React.createElement("svg", {
    width: 56,
    height: 1,
    viewBox: "0 0 56 1",
    fill: "none",
    style: {
      position: "relative",
      width: 56,
      height: 1,
      flexShrink: 0,
      color: "rgb(28,25,57)"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 0.384 -0.5 L -0.616 -0.5 L -0.616 1.5 L 0.384 1.5 L 0.384 0.5 L 0.384 -0.5 Z M 55.616 1.5 L 56.616 1.5 L 56.616 -0.5 L 55.616 -0.5 L 55.616 0.5 L 55.616 1.5 Z M 0.384 0.5 L 0.384 1.5 L 55.616 1.5 L 55.616 0.5 L 55.616 -0.5 L 0.384 -0.5 L 0.384 0.5 Z",
    fill: "currentColor",
    fillRule: "nonzero"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      display: "flex",
      flexDirection: "column",
      gap: 12,
      alignItems: "center",
      flexWrap: "nowrap",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 24,
      whiteSpace: "nowrap",
      lineHeight: "28px",
      letterSpacing: "-0.020em",
      color: "rgb(28,25,57)",
      flexShrink: 0
    }
  }, "X"), /*#__PURE__*/React.createElement("svg", {
    width: 56,
    height: 1,
    viewBox: "0 0 56 1",
    fill: "none",
    style: {
      position: "relative",
      width: 56,
      height: 1,
      flexShrink: 0,
      color: "rgb(28,25,57)"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 0.384 -0.5 L -0.616 -0.5 L -0.616 1.5 L 0.384 1.5 L 0.384 0.5 L 0.384 -0.5 Z M 55.616 1.5 L 56.616 1.5 L 56.616 -0.5 L 55.616 -0.5 L 55.616 0.5 L 55.616 1.5 Z M 0.384 0.5 L 0.384 1.5 L 55.616 1.5 L 55.616 0.5 L 55.616 -0.5 L 0.384 -0.5 L 0.384 0.5 Z",
    fill: "currentColor",
    fillRule: "nonzero"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      display: "flex",
      flexDirection: "column",
      gap: 12,
      alignItems: "center",
      flexWrap: "nowrap",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      fontFamily: "\"SF Pro Display\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
      fontWeight: 600,
      fontSize: 24,
      whiteSpace: "nowrap",
      lineHeight: "28px",
      letterSpacing: "-0.020em",
      color: "rgb(28,25,57)",
      flexShrink: 0
    }
  }, "X"), /*#__PURE__*/React.createElement("svg", {
    width: 56,
    height: 1,
    viewBox: "0 0 56 1",
    fill: "none",
    style: {
      position: "relative",
      width: 56,
      height: 1,
      flexShrink: 0,
      color: "rgb(28,25,57)"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 0.384 -0.5 L -0.616 -0.5 L -0.616 1.5 L 0.384 1.5 L 0.384 0.5 L 0.384 -0.5 Z M 55.616 1.5 L 56.616 1.5 L 56.616 -0.5 L 55.616 -0.5 L 55.616 0.5 L 55.616 1.5 Z M 0.384 0.5 L 0.384 1.5 L 55.616 1.5 L 55.616 0.5 L 55.616 -0.5 L 0.384 -0.5 L 0.384 0.5 Z",
    fill: "currentColor",
    fillRule: "nonzero"
  }))))));
}

// Globals for scripts loaded after this file.
window.PhotoVerifyCorners = PhotoVerifyCorners;
window.PhotoVerify1 = PhotoVerify1;
window.PhotoVerify2 = PhotoVerify2;