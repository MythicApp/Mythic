//
//  ProgressViewWithError.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

import SwiftUI

struct ProgressViewSheetWithError: View {
    @Binding var isError: Bool
    @Binding var isPresented: Bool
    
    var body: some View {
        if !isError {
            ProgressViewSheet(isPresented: $isPresented)
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.large)
                .padding()
        }
    }
}
